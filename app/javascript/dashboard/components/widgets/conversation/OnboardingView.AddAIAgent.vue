<script setup>
import { defineProps } from 'vue';
import Bot from '../../../routes/dashboard/settings/agentBots/Index.vue';

const props = defineProps({
    currentStep: {
        type: Number,
        required: true
    },
    stepNumber:{
        type:Number,
        required:true
    },
})
</script>

<template>
    <div v-if="currentStep === props.stepNumber">
       <Bot/>
    </div>
</template>