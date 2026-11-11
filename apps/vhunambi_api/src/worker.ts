import { app } from './server.js';
import type {
  CfExecutionContext,
  VhunambiWorkerEnv,
} from './types/cloudflare_worker_types.js';
export {
  GenerationSessionDO,
  broadcastGenerationEventToDo,
  type GenerationPipelineEventPayload,
} from './modules/realtime/generation_session_do.js';

export default {
  async fetch(
    request: Request,
    env: VhunambiWorkerEnv,
    ctx: CfExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/ws/generation' && env?.GENERATION_DO) {
      const generationId = url.searchParams.get('id') || 'default';
      const id = env.GENERATION_DO.idFromName(generationId);
      const stub = env.GENERATION_DO.get(id);
      return stub.fetch(request);
    }
    return app.fetch(request, env, {
      waitUntil: (promise: Promise<unknown>) => ctx.waitUntil(promise),
      passThroughOnException: () => ctx.passThroughOnException(),
      props: ctx.props ?? {},
    });
  },
};
