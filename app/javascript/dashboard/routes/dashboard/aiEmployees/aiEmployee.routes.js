import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from '../settings/SettingsWrapper.vue';
import Wrapper from '../settings/Wrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/ai-employees'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'ai_employees_list',
          component: () => import('./Index.vue'),
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/ai-employees'),
      component: Wrapper,
      props: params => {
        const showBackButton = params.name !== 'ai_employees_list';
        const fullWidth = params.name === 'ai_employees_show';
        return {
          headerTitle: 'AI_EMPLOYEES.HEADER',
          icon: 'i-lucide-bot',
          showBackButton,
          fullWidth,
        };
      },
      children: [
        {
          path: ':id',
          name: 'ai_employees_show',
          component: () => import('./Detail.vue'),
          meta: {
            permissions: ['administrator'],
          },
          props: route => ({ employeeId: route.params.id }),
        },
      ],
    },
  ],
};
