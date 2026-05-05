package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.uber.org/zap"
)

type Config struct {
	ServiceName     string
	HTTPAddr        string
	ShutdownTimeout time.Duration
	Environment     string
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func LoadConfig() Config {
	serviceName := getEnv("SERVICE_NAME", "match-service")
	httpAddr := getEnv("HTTP_ADDR", ":8080")
	env := getEnv("APP_ENV", "local")

	shutdownTimeout := 10 * time.Second
	if v := os.Getenv("SHUTDOWN_TIMEOUT"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			shutdownTimeout = d
		}
	}

	return Config{
		ServiceName:     serviceName,
		HTTPAddr:        httpAddr,
		ShutdownTimeout: shutdownTimeout,
		Environment:     env,
	}
}

func NewLogger(env string) (*zap.Logger, error) {
	if env == "production" {
		return zap.NewProduction()
	}
	return zap.NewDevelopment()
}

func main() {
	cfg := LoadConfig()
	logger, err := NewLogger(cfg.Environment)
	if err != nil {
		panic(err)
	}
	defer func() {
		_ = logger.Sync()
	}()

	logger = logger.With(
		zap.String("service", cfg.ServiceName),
		zap.String("env", cfg.Environment),
	)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	server := &http.Server{
		Addr:    cfg.HTTPAddr,
		Handler: mux,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	serverErr := make(chan error, 1)

	go func() {
		logger.Info("starting http server", zap.String("addr", cfg.HTTPAddr))

		err := server.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
			return
		}
		serverErr <- nil
	}()

	select {
	case err := <-serverErr:
		if err != nil {
			logger.Fatal("server failed", zap.Error(err))
		}
	case <-ctx.Done():
		logger.Info("shutdown signal received")

		shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()

		if err := server.Shutdown(shutdownCtx); err != nil {
			logger.Error("graceful shutdown failed", zap.Error(err))
			os.Exit(1)
		}

		logger.Info("server stopped gracefully")
	}
}
