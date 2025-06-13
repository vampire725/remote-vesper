package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"time"

	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"

	"trace-demo/common"
)

func main() {
	//cleanup := InitTracer("api-gateway")
	//defer cleanup()
	//
	//http.HandleFunc("/api/data", handleRequest)
	//log.Println("API Gateway starting on :8080")
	//log.Fatal(http.ListenAndServe(":8080", nil))

	common.InitLogger() // 初始化日志

	cleanup := common.InitTracer("api-gateway")
	defer cleanup()

	// 添加日志中间件
	http.Handle("/api/data", common.LoggingMiddleware(
		http.HandlerFunc(handleRequest),
	))

	log.Println("API Gateway starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	logger := common.GetLogger(ctx) // 获取上下文日志器traceID

	// 示例日志输出
	logger.Info("Handling API request",
		zap.String("userAgent", r.UserAgent()))

	//ctx := r.Context()

	spanCtx, span := common.Tracer.Start(ctx, "handle-request")
	defer span.End()

	// 调用后端服务
	backendResp, err := callBackendService(spanCtx)
	if err != nil {
		http.Error(w, "Backend service error", http.StatusInternalServerError)
		span.RecordError(err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(backendResp)
}

func callBackendService(ctx context.Context) ([]byte, error) {
	//spanCtx, span := common.Tracer.Start(ctx, "call-backend")
	//defer span.End()
	// API 网关调用后端服务时
	spanCtx, span := common.Tracer.Start(ctx, "call-backend", trace.WithSpanKind(trace.SpanKindClient))
	defer span.End()

	req, err := http.NewRequestWithContext(spanCtx, "GET", "http://localhost:8081/process", nil)
	if err != nil {
		return nil, err
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	return io.ReadAll(resp.Body)
}
