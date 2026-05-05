FROM golang:1.22.2-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /bin/service ./cmd

FROM alpine:3.20

RUN addgroup -S app && adduser -S app -G app
WORKDIR /app

COPY --from=builder /bin/service /app/service

EXPOSE 8080

ENV APP_ENV=local \
    HTTP_ADDR=:8080 \
    SHUTDOWN_TIMEOUT=10s

USER app

CMD ["/app/service"]
