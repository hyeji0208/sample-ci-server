import { Injectable } from '@nestjs/common';
import { HELLO_MESSAGE } from './app.constants';

@Injectable()
export class AppService {
  getHello(): string {
    return HELLO_MESSAGE;
  }
}
