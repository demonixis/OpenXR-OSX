// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <openxr/openxr.h>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <string>
#include <cstdint>

class Instance;
class Session;
class Swapchain;
class Space;
class ActionSetState;
class ActionState;

class Runtime
{
public:
    static Runtime& Get();

    // Handle management — cast our objects to/from XR handles
    template<typename T>
    XrResult RegisterHandle(uint64_t& outHandle, T* ptr)
    {
        std::lock_guard lock(handleMutex_);
        uint64_t h = nextHandle_++;
        handles_[h] = ptr;
        outHandle = h;
        return XR_SUCCESS;
    }

    template<typename T>
    T* FromHandle(uint64_t handle)
    {
        std::lock_guard lock(handleMutex_);
        auto it = handles_.find(handle);
        if (it == handles_.end())
        {
            return nullptr;
        }
        return static_cast<T*>(it->second);
    }

    void RemoveHandle(uint64_t handle)
    {
        std::lock_guard lock(handleMutex_);
        handles_.erase(handle);
    }

    // Path system
    XrResult StringToPath(const char* pathString, XrPath* path);
    XrResult PathToString(XrPath path, uint32_t bufferCapacityInput, uint32_t* bufferCountOutput, char* buffer);
    std::string GetPathString(XrPath path) const;

    // Current instance (only one allowed)
    Instance* GetInstance()
    {
        return instance_;
    }
    void SetInstance(Instance* inst)
    {
        instance_ = inst;
    }

private:
    Runtime() = default;

    std::mutex handleMutex_;
    uint64_t nextHandle_ = 1;
    std::unordered_map<uint64_t, void*> handles_;

    mutable std::mutex pathMutex_;
    uint64_t nextPath_ = 1;
    std::unordered_map<uint64_t, std::string> pathToString_;
    std::unordered_map<std::string, uint64_t> stringToPath_;

    Instance* instance_ = nullptr;
};
