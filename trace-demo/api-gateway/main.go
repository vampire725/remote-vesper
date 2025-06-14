package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"

	"trace-demo/common"
)

func main() {
	common.InitLogger()
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
	logger := common.GetLogger(ctx)

	// 创建根span
	ctx, span := common.Tracer.Start(ctx, "handle-request")
	defer span.End()

	// 示例日志输出
	logger.Info("开始处理 API 请求",
		zap.String("userAgent", r.UserAgent()),
		zap.String("path", r.URL.Path))

	// 添加HTTP属性
	span.SetAttributes(attribute.String("http.method", r.Method))
	span.SetAttributes(attribute.String("http.route", "/api/data"))

	// 调用后端服务 - 使用正确的上下文
	backendResp1, err := callBackendService1(ctx)
	if err != nil {
		http.Error(w, "Backend service 1 error", http.StatusInternalServerError)
		span.RecordError(err)
		logger.Error("Backend call failed", zap.Error(err))
		return
	}

	// 示例日志输出
	logger.Info("API 1 请求结束",
		zap.String("userAgent", r.UserAgent()),
		zap.String("path", r.URL.Path))

	w.Header().Set("Content-Type", "application/json")
	w.Write(backendResp1)

	// 调用后端服务 - 使用正确的上下文
	backendResp2, err := callBackendService2(ctx)
	if err != nil {
		http.Error(w, "Backend service 2 error", http.StatusInternalServerError)
		span.RecordError(err)
		logger.Error("Backend call failed", zap.Error(err))
		return
	}

	// 示例日志输出
	logger.Info("API 2 请求结束",
		zap.String("userAgent", r.UserAgent()),
		zap.String("path", r.URL.Path))

	w.Header().Set("Content-Type", "application/json")
	w.Write(backendResp2)
}

func callBackendService1(ctx context.Context) ([]byte, error) {
	// 创建客户端span
	ctx, span := common.Tracer.Start(
		ctx,
		"call-backend1",
		trace.WithSpanKind(trace.SpanKindClient),
	)
	defer span.End()

	// 添加HTTP调用属性
	span.SetAttributes(attribute.String("http.method", "GET"))
	span.SetAttributes(attribute.String("http.url", "http://localhost:8081/process"))
	span.SetAttributes(attribute.String("peer.service", "backend-service1"))

	req, err := http.NewRequestWithContext(ctx, "GET", "http://localhost:8081/process", nil)
	if err != nil {
		return nil, err
	}

	client := &http.Client{
		Timeout: 5 * time.Second,
		// 添加追踪拦截器
		Transport: common.NewTraceTransport(http.DefaultTransport),
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// 记录响应状态
	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	return io.ReadAll(resp.Body)
}

func callBackendService2(ctx context.Context) ([]byte, error) {
	// 创建客户端span
	ctx, span := common.Tracer.Start(
		ctx,
		"call-backend2",
		trace.WithSpanKind(trace.SpanKindClient),
	)
	defer span.End()

	// 添加HTTP调用属性
	span.SetAttributes(attribute.String("http.method", "GET"))
	span.SetAttributes(attribute.String("http.url", "http://localhost:8082/process"))
	span.SetAttributes(attribute.String("peer.service", "backend-service2"))

	req, err := http.NewRequestWithContext(ctx, "GET", "http://localhost:8082/process", nil)
	if err != nil {
		return nil, err
	}

	client := &http.Client{
		Timeout: 5 * time.Second,
		// 添加追踪拦截器
		Transport: common.NewTraceTransport(http.DefaultTransport),
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// 记录响应状态
	span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))

	return io.ReadAll(resp.Body)
}
