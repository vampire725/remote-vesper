package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"

	"trace-demo/common"

	"go.uber.org/zap"
)

func main() {
	common.InitLogger()
	cleanup := common.InitTracer("backend-service")
	defer cleanup()

	// 统一使用 /process 路径
	http.Handle("/process", common.LoggingMiddleware(
		http.HandlerFunc(processHandler),
	))

	log.Println("Backend service starting on :8081")
	log.Fatal(http.ListenAndServe(":8081", nil))
}

func processHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	logger := common.GetLogger(ctx)

	// 创建服务端span (仅在此处创建)
	ctx, span := common.Tracer.Start(
		ctx,
		"process-request",
		trace.WithSpanKind(trace.SpanKindServer),
	)
	defer span.End()

	// 添加HTTP属性
	span.SetAttributes(attribute.String("http.method", r.Method))
	span.SetAttributes(attribute.String("http.route", "/process"))

	// 模拟处理时间
	time.Sleep(100 * time.Millisecond)

	response := map[string]string{
		"status": "processed",
		"time":   time.Now().Format(time.RFC3339),
	}

	logger.Debug("开始处理后端服务",
		zap.String("step", "data_start"))

	// 处理业务逻辑 - 传递上下文
	processBusinessLogic(ctx)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	// 记录响应状态
	span.SetAttributes(attribute.Int("http.status_code", http.StatusOK))
}

func processBusinessLogic(ctx context.Context) {
	logger := common.GetLogger(ctx)

	// 创建内部span (不设置SpanKind，默认为Internal)
	_, span := common.Tracer.Start(ctx, "business-logic")
	defer span.End()

	// 添加业务属性
	span.SetAttributes(attribute.String("processing.stage", "validation"))

	logger.Debug("Processing business logic",
		zap.String("step", "data_validation"))

	time.Sleep(50 * time.Millisecond)

	logger.Info("Business logic completed",
		zap.Int("items_processed", 42))

	// 添加完成属性
	span.SetAttributes(attribute.Int("items.processed", 42))
}
