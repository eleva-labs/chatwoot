<script setup>
import Index from '../../../routes/dashboard/settings/agents/Index.vue';
import { defineProps } from 'vue';

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
    <div v-if="props.currentStep === props.stepNumber">
        <Index />  
    </div>
</template>