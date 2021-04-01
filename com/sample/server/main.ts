import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { GrpcOptions, Transport } from '@nestjs/microservices';
import { COM_SAMPLE_PROTO_PACKAGE_NAME } from 'bazel-ts/com/sample/proto/sample_service';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger();
  const app = await NestFactory.createMicroservice<GrpcOptions>(AppModule, {
    options: {
      package: [COM_SAMPLE_PROTO_PACKAGE_NAME],
      protoPath: [`${COM_SAMPLE_PROTO_PACKAGE_NAME.replace(/\./g, "/")}/sample_service.proto`],
      url: 'localhost:5000',  
    },
    transport: Transport.GRPC
  });

  await app.listenAsync();

  logger.log('application started');
}

bootstrap();
