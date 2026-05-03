import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import * as jwt from 'jsonwebtoken';

@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();

    // For MVP: accept x-user-id header directly, or validate JWT
    const userId = request.headers['x-user-id'];
    if (userId) {
      request.userId = userId;
      return true;
    }

    const authHeader = request.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing authorization');
    }

    const token = authHeader.slice(7);
    try {
      const secret = process.env.JWT_SECRET || 'dev-secret';
      const decoded = jwt.verify(token, secret) as { sub: string };
      request.userId = decoded.sub;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}
