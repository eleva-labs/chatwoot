<script>
import Modal from '../../Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    Modal,
    NextButton,
  },
  props: {
    title: {
      type: String,
      default: 'This is a title',
    },
    description: {
      type: String,
      default: 'This is your description',
    },
    confirmLabel: {
      type: String,
      default: 'Yes',
    },
    cancelLabel: {
      type: String,
      default: 'No',
    },
    details: {
      type: Array,
      default: () => [],
    },
  },
  data: () => ({
    show: false,
    resolvePromise: undefined,
    rejectPromise: undefined,
  }),

  methods: {
    showConfirmation() {
      this.show = true;
      return new Promise((resolve, reject) => {
        this.resolvePromise = resolve;
        this.rejectPromise = reject;
      });
    },
    confirm() {
      this.resolvePromise(true);
      this.show = false;
    },

    cancel() {
      this.resolvePromise(false);
      this.show = false;
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="cancel">
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header :header-title="title" :header-content="description">
        <div v-if="details.length" class="w-full mt-4">
          <div class="border-t border-n-weak dark:border-n-slate-6" />
          <div class="mt-4 text-sm leading-5 text-n-slate-11">
            <div v-for="detail in details" :key="detail" class="mb-2 last:mb-0">
              {{ detail }}
            </div>
          </div>
        </div>
      </woot-modal-header>
      <div class="flex flex-row justify-end gap-2 py-4 px-6 w-full">
        <NextButton faded type="reset" :label="cancelLabel" @click="cancel" />
        <NextButton type="submit" :label="confirmLabel" @click="confirm" />
      </div>
    </div>
  </Modal>
</template>
