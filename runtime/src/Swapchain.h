// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <openxr/openxr.h>
#ifdef XR_USE_GRAPHICS_API_VULKAN
#include <vulkan/vulkan.h>
#endif
#include <openxr/openxr_platform.h>
#include <vector>
#include <cstdint>
#include <deque>
#include <mutex>

enum class GraphicsApi
{
    Metal,
    Vulkan,
};

class Swapchain
{
public:
    // Metal constructor
    Swapchain(void* metalDevice, const XrSwapchainCreateInfo* createInfo);

    // Vulkan constructor (also takes metalDevice for debug renderer MTLTexture extraction)
    Swapchain(GraphicsApi api, void* metalDevice,
              void* vkDevice, void* vkPhysicalDevice,
              const XrSwapchainCreateInfo* createInfo);

    ~Swapchain();

    uint64_t GetHandle() const
    {
        return handle_;
    }

    GraphicsApi GetGraphicsApi() const
    {
        return graphicsApi_;
    }

    XrResult EnumerateImages(uint32_t imageCapacityInput, uint32_t* imageCountOutput,
                              XrSwapchainImageBaseHeader* images);
    XrResult AcquireImage(const XrSwapchainImageAcquireInfo* acquireInfo, uint32_t* index);
    XrResult WaitImage(const XrSwapchainImageWaitInfo* waitInfo);
    XrResult ReleaseImage(const XrSwapchainImageReleaseInfo* releaseInfo);

    uint32_t GetWidth() const
    {
        return width_;
    }
    uint32_t GetHeight() const
    {
        return height_;
    }
    int64_t GetFormat() const
    {
        return format_;
    }
    uint32_t GetImageCount() const
    {
        return imageCount_;
    }

    // Get the most recently released texture (MTLTexture* for debug rendering)
    void* GetLastReleasedTexture() const;

    // Get a texture view for a specific array slice of the last released texture.
    // For non-array textures (arraySize==1), returns the texture as-is.
    // Caller must call ReleaseTextureSlice() on the returned pointer when done.
    void* GetLastReleasedTextureSlice(uint32_t arrayIndex) const;

    // Release a texture view obtained from GetLastReleasedTextureSlice.
    static void ReleaseTextureSlice(void* textureSlice);

    // Monotonic value signaled on the shared event by the most recent snapshot.
    // Before reading the matching staging texture, the encoder waits on this value
    // (encodeWaitForEvent, a GPU-side wait for the snapshot copy to complete).
    // 0 means no snapshot yet (the caller falls back to referencing the slot).
    uint64_t GetLastSnapshotValue() const;

    uint32_t GetArraySize() const
    {
        return arraySize_;
    }

    bool HasReleasedImage() const;

    static constexpr uint32_t SwapchainImageCount = 3;

    // Picture-going-backwards root-cause fix: the encoder is asynchronous and reads
    // a swapchain slot via a blit on its own command queue, while Unity reuses the
    // same set of slots to render later frames — so the content the encoder reads
    // gets clobbered by that asynchronous reuse (confirmed by a discriminating
    // experiment: increasing the buffer count made the contamination span larger
    // and the judder worse). The fix: at ReleaseImage time, use Unity's own queue
    // to snapshot the current slot's contents into a separate pool of staging
    // textures (not part of Unity's reuse cycle), and have GetLastReleasedTextureSlice
    // return a staging view, so the content the encoder reads is fixed as of release.
    // Only needs to cover the frames in flight between a slot's release and the encoder
    // reading its snapshot; with the latest-frame-only encode queue that is ~2-3, so 4
    // is a safe round-up that keeps the extra resident-texture memory low.
    static constexpr uint32_t StagingImageCount = 4;

private:
    enum class ImageState
    {
        Available,
        Acquired,
        Waited,
    };

    void InitMetal(void* metalDevice, const XrSwapchainCreateInfo* createInfo);
    void InitVulkan(void* metalDevice, void* vkDevice, void* vkPhysicalDevice,
                     const XrSwapchainCreateInfo* createInfo);

    uint64_t handle_ = 0;
    GraphicsApi graphicsApi_ = GraphicsApi::Metal;
    uint32_t width_ = 0;
    uint32_t height_ = 0;
    int64_t format_ = 0;
    uint32_t arraySize_ = 1;
    uint32_t imageCount_ = SwapchainImageCount;

    void* device_ = nullptr; // MTL::Device*
    std::vector<void*> textures_; // MTL::Texture* (always Metal textures, for debug rendering)

    // Vulkan resources (only used when graphicsApi_ == Vulkan)
    void* vkDevice_ = nullptr;
    std::vector<uint64_t> vkImages_;   // VkImage handles
    std::vector<uint64_t> vkMemories_; // VkDeviceMemory handles

    uint32_t nextAcquireIndex_ = 0;
    uint32_t lastReleasedIndex_ = 0;
    bool staticImageAcquired_ = false;
    bool hasReleasedImage_ = false;

    // Separate snapshot texture pool (see StagingImageCount). Only used on the
    // Metal path and only once Unity's command queue is available.
    std::vector<void*> stagingTextures_; // MTL::Texture*, same descriptor as swapchain textures
    uint32_t stagingWriteIndex_ = 0;     // next staging slot to write (round-robin)
    uint32_t lastSnapshotIndex_ = 0;     // staging slot of the most recent snapshot
    uint64_t lastSnapshotValue_ = 0;     // value signaled on the shared event by that snapshot
    bool hasSnapshot_ = false;           // whether at least one snapshot has been produced
    std::vector<ImageState> imageStates_;
    std::deque<uint32_t> acquiredImageOrder_;
    mutable std::mutex stateMutex_;
};
