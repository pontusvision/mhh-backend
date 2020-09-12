import { 
  APIGatewayProxyEvent, 
  APIGatewayProxyResult 
} from "aws-lambda";

const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  const queries = JSON.stringify(event);
  return {
    statusCode: 200,
    body: `Queries: ${queries}`
  }
}

export {handler}
