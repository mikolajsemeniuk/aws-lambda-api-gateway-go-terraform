package main

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	lambda.Start(handler)
}

type output struct {
	Message string `json:"message"`
}

func handler(c context.Context, r events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	payload := output{
		Message: "Hello from Go Lambda!",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(body),
	}, nil
}
