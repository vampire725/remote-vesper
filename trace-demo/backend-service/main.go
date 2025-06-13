package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"go.opentelemetry.io/otel/trace"

	"trace-demo/common"

	"go.uber.org/zap"
)

//var tracer trace.Tracer

//func init() {
//    tracer = otel.Tracer("backend-service")
//}

func main() {
	//cleanup := InitTracer("backend-service")
	//defer cleanup()
	//
	//http.HandleFunc("/process", processHandler)
	//log.Println("Backend service starting on :8081")
	//log.Fatal(http.ListenAndServe(":8081", nil))

	common.InitLogger() // 初始化日志

	cleanup := common.InitTracer("backend-service")
	defer cleanup()

	// 添加日志中间件
	http.Handle("/process", common.LoggingMiddleware(
		http.HandlerFunc(processHandler),
	))

	log.Println("Backend service starting on :8081")
	log.Fatal(http.ListenAndServe(":8081", nil))
}

func processHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	spanCtx, span := common.Tracer.Start(ctx, "process-data")
	defer span.End()

	// 模拟处理时间
	time.Sleep(100 * time.Millisecond)

	response := map[string]string{
		"status": "processed",
		"time":   time.Now().Format(time.RFC3339),
	}

	processBusinessLogic(spanCtx)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func processBusinessLogic(ctx context.Context) {

	logger := common.GetLogger(ctx)
	// 后端服务处理请求时
	_, span := common.Tracer.Start(ctx, "process-data", trace.WithSpanKind(trace.SpanKindServer))
	defer span.End()

	// 业务日志示例
	logger.Debug("Processing business logic",
		zap.String("step", "data_validation"))

	time.Sleep(50 * time.Millisecond)

	logger.Info("Business logic completed",
		zap.Int("items_processed", 42))
}
