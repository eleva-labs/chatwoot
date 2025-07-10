<script setup>
import { computed,shallowRef, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useMapGetter } from 'dashboard/composables/store';
import Button from '../../../../shared/components/Button.vue';
import OnboardingViewAddAgent from './OnboardingView.AddAgent.vue';
import OnboardingViewAddChannel from './OnboardingView.AddChannel.vue';
import OnboardingViewAddAIAgent from './OnboardingView.AddAIAgent.vue';
import store from '../../../store';
import StepCircleFlow from '../../../../shared/components/StepCircleFlow.vue';

const getters = useStoreGetters();

const { t } = useI18n();
const globalConfig = computed(() => getters['globalConfig/get'].value);
const currentUser = computed(() => getters.getCurrentUser.value);
const isLoading = ref(true)

const agents = useMapGetter("agents/getAgents");
const inboxes = useMapGetter("inboxes/getInboxes");
const bots = useMapGetter("bots/getBots");
const currentStep = shallowRef(1)
const stepCompletionStatus = ref({})
const stepOrder = shallowRef({
  addAgentsStep: 1,
  addChannelStep: 2,
  addAIAgentStep: 3
})
const onboardingSteps = shallowRef({
  [stepOrder.value.addAgentsStep]:{
    title: t('ONBOARDING.TEAM_MEMBERS.TITLE'),
    description: t('ONBOARDING.TEAM_MEMBERS.DESCRIPTION'),
    component: OnboardingViewAddAgent,
    props: {
      stepNumber: 1,
    },
    icon: {
      src: "i-lucide-users",
      class: "size-8 bg-white"
    },
    isStepCompleted: stepCompletionStatus.value[stepOrder.value.addAgentsStep]
  },
  [stepOrder.value.addChannelStep]:{
    title: t('ONBOARDING.ADD_CHANNEL.TITLE'),
    description: t('ONBOARDING.ADD_CHANNEL.DESCRIPTION'),
    component: OnboardingViewAddChannel,
    props: {
      stepNumber: 2,
    },
    icon: {
      src: "i-lucide-messages-square",
      class: "size-8 bg-white"
    },
    isStepCompleted: stepCompletionStatus.value[stepOrder.value.addChannelStep]
  },
  [stepOrder.value.addAIAgentStep]:{
    title: t('ONBOARDING.ADD_AI_AGENT.TITLE'),
    description: t('ONBOARDING.ADD_AI_AGENT.DESCRIPTION'),
    component: OnboardingViewAddAIAgent,
    props: {
      stepNumber: 3,
    },
    icon: {
      src: "i-lucide-bot-message-square",
      class: "size-8 bg-white"
    },
    isStepCompleted: stepCompletionStatus.value[stepOrder.value.addAIAgentStep]
  },
})

const greetingMessage = computed(() => {
  const hours = new Date().getHours();
  let translationKey;
  if (hours < 12) {
    translationKey = 'ONBOARDING.GREETING_MORNING';
  } else if (hours < 18) {
    translationKey = 'ONBOARDING.GREETING_AFTERNOON';
  } else {
    translationKey = 'ONBOARDING.GREETING_EVENING';
  }
  return t(translationKey, {
    name: currentUser.value.name,
    installationName: globalConfig.value.installationName,
  });
});


async function setStepCompletionStatus(stepName) {
  stepCompletionStatus.value[stepName] = true
}


function startWatchers() {
  watch(agents,async(newAgents) => {
    if(newAgents && newAgents.length >= 2){
      setStepCompletionStatus(stepOrder.value.addAgentsStep)
      console.log("stepCompletionStatus",stepCompletionStatus.value)
  }
},{deep: true})

watch(inboxes,async(newInboxes) => {
  if(newInboxes && newInboxes.length > 0){
    const inboxesMembers = await store.dispatch('inboxMembers/get', {inboxId: newInboxes[0].id})
    if(inboxesMembers?.data?.payload?.length >= 1){
      setStepCompletionStatus(stepOrder.value.addChannelStep)
    }
  }
},{deep: true})

watch(bots,async(newBots) => {
  if(newBots && newBots.length > 0){
    setStepCompletionStatus(stepOrder.value.addAIAgentStep)
  }
},{deep: true})

}

function finishHandler() {
  console.log("finish")
}

function backHandler() {
  currentStep.value--
}

function nextHandler() {
  currentStep.value++
}

onMounted(async () => {
  startWatchers()
  setTimeout(() => {
    isLoading.value = false
  }, 1000)
})

</script>

<template>
  <div v-if="!isLoading" class="flex flex-col min-h-screen lg:max-w-5xl max-w-4xl gap-4 p-8 w-full font-inter overflow-auto">
    <!--Greeting-->
    <section class="w-full mx-auto">
      <p class="text-xl font-semibold text-slate-900 dark:text-white font-interDisplay tracking-[0.3px]">
        {{ greetingMessage }}
      </p>
      <p class="text-slate-600 dark:text-slate-400 text-base">
        {{
          $t('ONBOARDING.DESCRIPTION', {
            installationName: globalConfig.installationName,
          })
        }}
      </p>
    </section>

    <section class=" flex flex-col my-4 mb-10 h-full gap-4  ">
      <!--Circle Step Indicator-->
      <StepCircleFlow :steps="onboardingSteps" :currentStep="currentStep" :stepsCompleted="stepCompletionStatus" />

      <!--OnboardingViews-->
      <div class="h-full my-8 w-full mx-auto">
          <component :is="onboardingSteps[currentStep].component" v-bind="onboardingSteps[currentStep].props"
          :currentStep="currentStep" />
        <!--Navigation Buttons-->
        <div class="flex mt-10 justify-between">
          <div> <Button v-if="currentStep > 1" @click="backHandler"> Back </Button></div>
          <div>
            <Button v-if="currentStep < Object.keys(onboardingSteps).length" :disabled="!stepCompletionStatus[currentStep]" @click="nextHandler"> Next </Button>
            <Button v-if="currentStep == Object.keys(onboardingSteps).length && stepCompletionStatus[currentStep]"
              @click="finishHandler()"> Finish </Button>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>


