package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
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

	if lc, ok := lambdacontext.FromContext(c); ok {
		fmt.Println("RequestID: ", lc.AwsRequestID, ", Lambda triggered!")
	}

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(body),
	}, nil
}
