import { Controller } from "@nestjs/common";
import { GrpcMethod } from '@nestjs/microservices';
import { SampleResponse, SampleServiceController } from "bazel-ts/com/sample/proto/sample_service";

@Controller()
class AppController implements SampleServiceController {
  // Doesn't actually get hooked up as a grpc service just stubbing for type checking
  @GrpcMethod('SampleService', 'sampleRequest')
  sampleRequest(): SampleResponse {
    return { count: 1 }
  }
}

export { AppController };
