package common

import (
	"context"
	"log"
	"net/http"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"go.opentelemetry.io/otel/trace"
)

var Tracer trace.Tracer

func InitTracer(serviceName string) func() {
	ctx := context.Background()

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion("1.0.0"),
			attribute.String("environment", "dev"),
			attribute.String("tempo.compatibility", "2.6.0"),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	// 使用带超时的连接
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	conn, err := grpc.DialContext(ctx, "localhost:4317",
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		log.Fatal("Failed to create gRPC connection to Tempo:", err)
	}

	traceClient := otlptracegrpc.NewClient(
		otlptracegrpc.WithGRPCConn(conn),
	)
	traceExp, err := otlptrace.New(ctx, traceClient)
	if err != nil {
		log.Fatal(err)
	}

	bsp := sdktrace.NewBatchSpanProcessor(traceExp)
	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithResource(res),
		sdktrace.WithSpanProcessor(bsp),
	)

	// 设置全局传播器（Tempo 2.6.0 需要）
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)

	otel.SetTracerProvider(tracerProvider)
	Tracer = tracerProvider.Tracer(serviceName)

	return func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err = tracerProvider.Shutdown(shutdownCtx); err != nil {
			log.Fatal("Tracer provider shutdown error:", err)
		}
	}
}

// 追踪感知的 HTTP Transport
type traceTransport struct {
	transport http.RoundTripper
}

func NewTraceTransport(transport http.RoundTripper) *traceTransport {
	return &traceTransport{transport: transport}
}

func (t *traceTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// 为 Tempo 2.6.0 正确注入头部
	ctx := req.Context()
	propagator := otel.GetTextMapPropagator()
	propagator.Inject(ctx, propagation.HeaderCarrier(req.Header))

	// 添加自定义头部（可选）
	req.Header.Set("X-Tempo-Version", "2.6.0")

	return t.transport.RoundTrip(req)
}
