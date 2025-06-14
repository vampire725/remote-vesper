package common

import (
	"context"
	"log"
	"net"
	"net/http"
	"time"

	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
)

/*
 * @Author: Gpp
 * @File:   logger.go
 * @Date:   2025/6/8 上午1:02
 */

// Logger 初始化全局
var Logger *zap.Logger

func InitLogger() {
	config := zap.NewProductionConfig()
	config.OutputPaths = []string{"../../docker-compose/vector/log/myapp.log"}
	Logger, _ = config.Build()

	defer Logger.Sync()

	//go sendToLogstash()
}

func sendToLogstash() {
	conn, err := net.Dial("tcp", "localhost:5001")
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	// 假设 logger.Info 已格式化为 JSON
	logger := GetLogger(context.Background())
	logger.Info("Test log", zap.String("traceID", "test123"))

	// 需实现将日志发送到 conn
}

// 日志中间件：为每个请求注入 TraceID
//func LoggingMiddleware(next http.Handler) http.Handler {
//    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
//        start := time.Now()
//        ctx := r.Context()
//
//        // 获取 TraceID
//        var traceID string
//        if span := trace.SpanContextFromContext(ctx); span.IsValid() {
//            traceID = span.TraceID().String()
//        }
//
//        // 创建带 TraceID 的子日志器
//        logger := Logger.With(
//            zap.String("traceID", traceID),
//            zap.String("method", r.Method),
//            zap.String("path", r.URL.Path),
//        )
//
//        // 将日志器存入上下文
//        ctx = context.WithValue(ctx, "logger", logger)
//        r = r.WithContext(ctx)
//
//        // 执行请求
//        next.ServeHTTP(w, r)
//
//        // 记录请求完成
//        logger.Info("Request completed",
//            zap.Duration("duration", time.Since(start)),
//        )
//    })
//}

func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ctx := r.Context()

		// 强制创建 Span
		ctx, span := Tracer.Start(ctx, "http-request")
		defer span.End()

		var traceID, spanID, spanName string

		if spanCtx := trace.SpanContextFromContext(ctx); spanCtx.IsValid() {
			traceID = spanCtx.TraceID().String()
			spanID = spanCtx.SpanID().String()
			spanName = "unknown" // 默认值
			if s, ok := span.(sdktrace.ReadOnlySpan); ok {
				spanName = s.Name() // 获取 Span 操作名称
			}
		}

		// 创建带追踪上下文的日志器
		logger := Logger.With(
			zap.String("traceID", traceID),
			zap.String("spanID", spanID),
			zap.String("spanName", spanName),
			zap.String("method", r.Method),
			zap.String("path", r.URL.Path),
		)

		ctx = context.WithValue(ctx, "logger", logger)
		r = r.WithContext(ctx)

		next.ServeHTTP(w, r)

		logger.Info("Request completed",
			zap.Duration("duration", time.Since(start)),
		)
	})
}

// GetLogger 从上下文中获取日志器
func GetLogger(ctx context.Context) *zap.Logger {
	if logger, ok := ctx.Value("logger").(*zap.Logger); ok {
		return logger
	}
	return Logger
}
