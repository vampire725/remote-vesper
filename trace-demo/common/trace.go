package common

import (
	"context"
	"log"
	"time"

	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
	"google.golang.org/grpc"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/trace"
)

/*
 * @Author: Gpp
 * @File:   trace.go
 * @Date:   2025/6/8 下午5:05
 */

var Tracer trace.Tracer

//func init() {
//    Tracer = otel.Tracer("api-gateway")
//}

func InitTracer(serviceName string) func() {
	ctx := context.Background()

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	conn, err := grpc.Dial("localhost:4316", grpc.WithInsecure())
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

	Tracer = tracerProvider.Tracer(serviceName)
	otel.SetTracerProvider(tracerProvider)

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := tracerProvider.Shutdown(ctx); err != nil {
			log.Fatal(err)
		}
	}
}
