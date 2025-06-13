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
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	// 使用安全连接选项
	conn, err := grpc.Dial("localhost:4317", // 使用标准端口4317
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		log.Fatal(err)
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

	// 设置全局传播器
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)

	otel.SetTracerProvider(tracerProvider)
	Tracer = tracerProvider.Tracer(serviceName)

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := tracerProvider.Shutdown(ctx); err != nil {
			log.Fatal(err)
		}
	}
}

// 添加HTTP追踪传输层
type traceTransport struct {
	transport http.RoundTripper
}

func NewTraceTransport(transport http.RoundTripper) *traceTransport {
	return &traceTransport{transport: transport}
}

func (t *traceTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// 注入追踪上下文
	ctx := req.Context()
	otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(req.Header))

	return t.transport.RoundTrip(req)
}
