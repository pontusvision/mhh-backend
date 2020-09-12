#!/bin/bash

API_NAME=api
REGION=eu-west-2
STAGE=test

function fail() {
    echo $2
    exit $1
}

DIR="$( cd "$(dirname "$0")" ; pwd -P )"

cd "${DIR}"

if [[ ! -f ~/.aws/credentials ]]; then
  cp -a ${DIR}/.aws ~/
fi
#export AWS_LOCAL="docker run --rm -ti  -v ${DIR}/.aws:/root/.aws -v ${DIR}:/aws amazon/aws-cli"
#pip install awscli
export AWS_LOCAL="aws --endpoint-url=http://localhost:4566"

yarn install
yarn compile
yarn prune

zip -r api-handler.zip  built node_modules package.json yarn.lock

${AWS_LOCAL} lambda create-function \
    --region ${REGION} \
    --function-name ${API_NAME} \
    --runtime nodejs12.x \
    --handler built/app.lambdaHandler \
    --memory-size 128 \
    --zip-file fileb://api-handler.zip \
    --role arn:aws:iam::123456:role/irrelevant

[ $? == 0 ] || fail 1 "Failed: AWS / lambda / create-function"

LAMBDA_ARN=$(${AWS_LOCAL} lambda list-functions --query "Functions[?FunctionName==\`${API_NAME}\`].FunctionArn" --output text --region ${REGION})

${AWS_LOCAL} apigateway create-rest-api \
    --region ${REGION} \
    --name ${API_NAME}

[ $? == 0 ] || fail 2 "Failed: AWS / apigateway / create-rest-api"

API_ID=$(${AWS_LOCAL} apigateway get-rest-apis --query "items[?name==\`${API_NAME}\`].id" --output text --region ${REGION})
PARENT_RESOURCE_ID=$(${AWS_LOCAL} apigateway get-resources --rest-api-id ${API_ID} --query 'items[?path==`/`].id' --output text --region ${REGION})

${AWS_LOCAL} apigateway create-resource \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --parent-id ${PARENT_RESOURCE_ID} \
    --path-part "{somethingId}"

[ $? == 0 ] || fail 3 "Failed: AWS / apigateway / create-resource"

RESOURCE_ID=$(${AWS_LOCAL} apigateway get-resources --rest-api-id ${API_ID} --query 'items[?path==`/{somethingId}`].id' --output text --region ${REGION})

${AWS_LOCAL} apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --http-method GET \
    --request-parameters "method.request.path.somethingId=true" \
    --authorization-type "NONE" 

[ $? == 0 ] || fail 4 "Failed: AWS / apigateway / put-method"

${AWS_LOCAL} apigateway put-method \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --http-method POST \
    --authorization-type "NONE" 

[ $? == 0 ] || fail 5 "Failed: AWS / apigateway / put-method"

${AWS_LOCAL} apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method GET \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH 

[ $? == 0 ] || fail 6 "Failed: AWS / apigateway / put-integration"

${AWS_LOCAL} apigateway put-integration \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH 

[ $? == 0 ] || fail 7 "Failed: AWS / apigateway / put-integration"

${AWS_LOCAL} apigateway create-deployment \
    --region ${REGION} \
    --rest-api-id ${API_ID} \
    --stage-name ${STAGE} 

[ $? == 0 ] || fail 8 "Failed: AWS / apigateway / create-deployment"

ENDPOINT=http://localhost:4567/restapis/${API_ID}/${STAGE}/_user_request_/HowMuchIsTheFish

echo "API available at: ${ENDPOINT}"

echo "Testing GET:"
curl -i ${ENDPOINT}

echo "Testing POST:"
curl -iX POST ${ENDPOINT}
