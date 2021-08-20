<template>
  <div
    id="previewer"
    @mousemove="toggleNavigation"
    @touchstart="toggleNavigation"
  >
    <header-bar>
      <action icon="close" :label="$t('buttons.close')" @action="close()" />
      <title>{{ name }}</title>
      <action
        :disabled="loading"
        v-if="isResizeEnabled && req.type === 'image'"
        :icon="fullSize ? 'photo_size_select_large' : 'hd'"
        @action="toggleSize"
      />

      <template #actions>
        <action
          :disabled="loading"
          v-if="user.perm.rename"
          icon="mode_edit"
          :label="$t('buttons.rename')"
          show="rename"
        />
        <action
          :disabled="loading"
          v-if="user.perm.delete"
          icon="delete"
          :label="$t('buttons.delete')"
          @action="deleteFile"
          id="delete-button"
        />
        <action
          :disabled="loading"
          v-if="user.perm.download"
          icon="file_download"
          :label="$t('buttons.download')"
          @action="download"
        />
        <action
          :disabled="loading"
          icon="info"
          :label="$t('buttons.info')"
          show="info"
        />
      </template>
    </header-bar>

    <div class="loading delayed" v-if="loading">
      <div class="spinner">
        <div class="bounce1"></div>
        <div class="bounce2"></div>
        <div class="bounce3"></div>
      </div>
    </div>
    <template v-else>
      <div class="preview" style="width: 100%; height: 100%; margin: 0 auto">
        <ExtendedImage v-if="req.type == 'image'" :src="raw"></ExtendedImage>
        <audio
          v-else-if="req.type == 'audio'"
          ref="player"
          :src="raw"
          controls
          :autoplay="autoPlay"
          @play="autoPlay = true"
        ></audio>
        <div
          v-else-if="req.type == 'video'"
          style="width: 100%; height: 100%; margin: 0 auto"
        >
          <video-player
            class="video-player vjs-custom-skin"
            ref="videoPlayer"
            :options="playerOptions"
          >
          </video-player>
        </div>

        <!-- <video
          v-else-if="req.type == 'video'"
          ref="player"
          :src="raw"
          controls
          :autoplay="autoPlay"
          @play="autoPlay = true"
        >
          <track
            kind="captions"
            v-for="(sub, index) in subtitles"
            :key="index"
            :src="sub"
            :label="'Subtitle ' + index"
            :default="index === 0"
          />
          Sorry, your browser doesn't support embedded videos, but don't worry,
          you can <a :href="downloadUrl">download it</a>
          and watch it with your favorite video player!
        </video> -->
        <object
          v-else-if="req.extension.toLowerCase() == '.pdf'"
          class="pdf"
          :data="raw"
        ></object>
        <a v-else-if="req.type == 'blob'" :href="downloadUrl">
          <h2 class="message">
            {{ $t("buttons.download") }}
            <i class="material-icons">file_download</i>
          </h2>
        </a>
      </div>
    </template>

    <button
      @click="prev"
      @mouseover="hoverNav = true"
      @mouseleave="hoverNav = false"
      :class="{ hidden: !hasPrevious || !showNav }"
      :aria-label="$t('buttons.previous')"
      :title="$t('buttons.previous')"
    >
      <i class="material-icons">chevron_left</i>
    </button>
    <button
      @click="next"
      @mouseover="hoverNav = true"
      @mouseleave="hoverNav = false"
      :class="{ hidden: !hasNext || !showNav }"
      :aria-label="$t('buttons.next')"
      :title="$t('buttons.next')"
    >
      <i class="material-icons">chevron_right</i>
    </button>
  </div>
</template>

<script>
import { mapState } from "vuex";
import { files as api } from "@/api";
import { baseURL, resizePreview } from "@/utils/constants";
import url from "@/utils/url";
import throttle from "lodash.throttle";

import HeaderBar from "@/components/header/HeaderBar";
import Action from "@/components/header/Action";
import ExtendedImage from "@/components/files/ExtendedImage";

const mediaTypes = ["image", "video", "audio", "blob"];

export default {
  name: "preview",
  components: {
    HeaderBar,
    Action,
    ExtendedImage,
  },
  data: function () {
    return {
      previousLink: "",
      nextLink: "",
      listing: null,
      name: "",
      subtitles: [],
      fullSize: false,
      showNav: true,
      navTimeout: null,
      hoverNav: false,
      autoPlay: false,
      dp: null,
      source: "",
    };
  },
  computed: {
    ...mapState(["req", "user", "oldReq", "jwt", "loading", "show"]),
    hasPrevious() {
      return this.previousLink !== "";
    },
    hasNext() {
      return this.nextLink !== "";
    },
    downloadUrl() {
      console.log("startsWith:", this.req.url);
      if (this.req.url.startsWith("/share/")) {
        let queryArg = "";
        if (this.token !== "") {
          queryArg = `?token=${this.token}`;
        }
        const path = this.$route.path.split("/").splice(2).join("/");
        return `${baseURL}/api/public/dl/${path}${queryArg}`;
      }
      return `${baseURL}/api/raw${url.encodePath(this.req.path)}?auth=${
        this.jwt
      }`;
    },
    pubfullLink() {
      return window.location.origin + this.link;
    },
    previewUrl() {
      if (this.req.url.startsWith("/share/")) {
        let queryArg = "";
        if (this.token !== "") {
          queryArg = `?token=${this.token}`;
        }

        const path = this.$route.path.split("/").splice(2).join("/");
        return `${baseURL}/api/public/dl/${path}${queryArg}`;
      }
      // reload the image when the file is replaced
      const key = Date.parse(this.req.modified);

      if (this.req.type === "image" && !this.fullSize) {
        return `${baseURL}/api/preview/big${url.encodePath(
          this.req.path
        )}?k=${key}`;
      }
      return `${baseURL}/api/raw${url.encodePath(this.req.path)}?k=${key}`;
    },
    raw() {
      return `${this.previewUrl}&inline=true`;
    },
    showMore() {
      return this.$store.state.show === "more";
    },
    isResizeEnabled() {
      return resizePreview;
    },
    playerOptions() {
      return {
        // playbackRates: [0.7, 1.0, 1.5, 2.0], //播放速度
        autoplay: true, //如果true,浏览器准备好时开始回放。
        muted: false, // 默认情况下将会消除任何音频。
        loop: false, // 导致视频一结束就重新开始。
        preload: "auto", // 建议浏览器在<video>加载元素后是否应该开始下载视频数据。auto浏览器选择最佳行为,立即开始加载视频（如果浏览器支持）
        language: "zh-CN",
        // aspectRatio: '16:9', // 将播放器置于流畅模式，并在计算播放器的动态大小时使用该值。值应该代表一个比例 - 用冒号分隔的两个数字（例如"16:9"或"4:3"）
        fluid: true, // 当true时，Video.js player将拥有流体大小。换句话说，它将按比例缩放以适应其容器。
        sources: [
          {
            type: "video/mp4",
            src: `${this.previewUrl}`,
          },
        ],
        width: document.documentElement.clientWidth,
        notSupportedMessage: "此视频暂无法播放，请稍后再试", //允许覆盖Video.js无法播放媒体源时显示的默认信息。
        //        controlBar: {
        //          timeDivider: true,
        //          durationDisplay: true,
        //          remainingTimeDisplay: false,
        //          fullscreenToggle: true  //全屏按钮
        //        }
      };
    },
  },
  watch: {
    $route: function () {
      this.updatePreview();
      this.toggleNavigation();
    },
  },
  async mounted() {
    // window.addEventListener("keydown", this.key);
    this.listing = this.oldReq.items;
    this.updatePreview();
  },
  // beforeDestroy() {
  //   window.removeEventListener("keydown", this.key);
  // },
  methods: {
    deleteFile() {
      this.$store.commit("showHover", {
        prompt: "delete",
        confirm: () => {
          this.listing = this.listing.filter((item) => item.name !== this.name);

          if (this.hasNext) {
            this.next();
          } else if (!this.hasPrevious && !this.hasNext) {
            this.close();
          } else {
            this.prev();
          }
        },
      });
    },
    prev() {
      this.hoverNav = false;
      this.$router.push({ path: this.previousLink });
    },
    next() {
      this.hoverNav = false;
      this.$router.push({ path: this.nextLink });
    },
    // key(event) {
    //   if (this.show !== null) {
    //     return;
    //   }

    //   if (event.which === 13 || event.which === 39) {
    //     // right arrow
    //     if (this.hasNext) this.next();
    //   } else if (event.which === 37) {
    //     // left arrow
    //     if (this.hasPrevious) this.prev();
    //   } else if (event.which === 27) {
    //     // esc
    //     this.close();
    //   }
    // },
    async updatePreview() {
      if (
        this.$refs.player &&
        this.$refs.player.paused &&
        !this.$refs.player.ended
      ) {
        this.autoPlay = true;
      }

      if (this.req.subtitles) {
        this.subtitles = this.req.subtitles.map(
          (sub) => `${baseURL}/api/raw${sub}?inline=true`
        );
      }

      // let dirs = this.$route.fullPath.split("/");
      // this.name = decodeURIComponent(dirs[dirs.length - 1]);
      this.name = document.title;

      if (!this.listing) {
        try {
          const path = url.removeLastDir(this.$route.path);
          const res = await api.fetch(path);
          this.listing = res.items;
        } catch (e) {
          console.log("err:", e);
          // this.$showError(e);
        }
      }

      this.previousLink = "";
      this.nextLink = "";

      if (this.listing) {
        for (let i = 0; i < this.listing.length; i++) {
          if (this.listing[i].name !== this.name) {
            continue;
          }

          for (let j = i - 1; j >= 0; j--) {
            if (mediaTypes.includes(this.listing[j].type)) {
              this.previousLink = this.listing[j].url;
              break;
            }
          }

          for (let j = i + 1; j < this.listing.length; j++) {
            if (mediaTypes.includes(this.listing[j].type)) {
              this.nextLink = this.listing[j].url;
              break;
            }
          }
        }
        return;
      }
    },
    openMore() {
      this.$store.commit("showHover", "more");
    },
    resetPrompts() {
      this.$store.commit("closeHovers");
    },
    toggleSize() {
      this.fullSize = !this.fullSize;
    },
    toggleNavigation: throttle(function () {
      this.showNav = true;

      if (this.navTimeout) {
        clearTimeout(this.navTimeout);
      }

      this.navTimeout = setTimeout(() => {
        this.showNav = false || this.hoverNav;
        this.navTimeout = null;
      }, 1500);
    }, 500),
    close() {
      this.$store.commit("updateRequest", {});

      let uri = url.removeLastDir(this.$route.path) + "/";
      this.$router.push({ path: uri });
    },
    download() {
      window.open(this.downloadUrl);
    },
  },
};
</script>
