// SPDX-License-Identifier: MPL-2.0

#include "Runtime.h"
#include <cstring>
#include <cctype>
#include <string_view>

Runtime& Runtime::Get()
{
    // Use a heap-allocated singleton to avoid destruction order issues
    // when the dylib is unloaded (static locals can be destroyed before
    // other statics that reference them, causing mutex crashes)
    static Runtime* instance = new Runtime();
    return *instance;
}

XrResult Runtime::StringToPath(const char* pathString, XrPath* path)
{
    if (pathString == nullptr || path == nullptr)
    {
        return XR_ERROR_VALIDATION_FAILURE;
    }

    std::string str(pathString);
    if (str.empty() || str.size() >= XR_MAX_PATH_LENGTH || str[0] != '/')
    {
        return XR_ERROR_PATH_FORMAT_INVALID;
    }
    if (str.size() > 1 && str.back() == '/')
    {
        return XR_ERROR_PATH_FORMAT_INVALID;
    }
    if (str.find("//") != std::string::npos)
    {
        return XR_ERROR_PATH_FORMAT_INVALID;
    }

    size_t segmentStart = 1;
    while (segmentStart <= str.size())
    {
        size_t segmentEnd = str.find('/', segmentStart);
        if (segmentEnd == std::string::npos)
        {
            segmentEnd = str.size();
        }

        std::string_view segment(str.data() + segmentStart, segmentEnd - segmentStart);
        if (segment.empty() || segment == "." || segment == "..")
        {
            return XR_ERROR_PATH_FORMAT_INVALID;
        }

        segmentStart = segmentEnd + 1;
    }

    for (char ch : str)
    {
        if (ch == '/')
        {
            continue;
        }
        if (std::islower(static_cast<unsigned char>(ch)) ||
            std::isdigit(static_cast<unsigned char>(ch)) ||
            ch == '_' || ch == '-' || ch == '.')
        {
            continue;
        }
        return XR_ERROR_PATH_FORMAT_INVALID;
    }

    std::lock_guard lock(pathMutex_);

    auto it = stringToPath_.find(str);
    if (it != stringToPath_.end())
    {
        *path = it->second;
        return XR_SUCCESS;
    }

    uint64_t p = nextPath_++;
    stringToPath_[str] = p;
    pathToString_[p] = str;
    *path = p;
    return XR_SUCCESS;
}

XrResult Runtime::PathToString(XrPath path, uint32_t bufferCapacityInput, uint32_t* bufferCountOutput, char* buffer)
{
    if (bufferCountOutput == nullptr)
    {
        return XR_ERROR_VALIDATION_FAILURE;
    }

    std::lock_guard lock(pathMutex_);

    auto it = pathToString_.find(path);
    if (it == pathToString_.end())
    {
        return XR_ERROR_PATH_INVALID;
    }

    const std::string& str = it->second;
    uint32_t needed = static_cast<uint32_t>(str.size() + 1);
    *bufferCountOutput = needed;

    if (bufferCapacityInput == 0)
    {
        return XR_SUCCESS;
    }

    if (bufferCapacityInput < needed)
    {
        return XR_ERROR_SIZE_INSUFFICIENT;
    }

    std::memcpy(buffer, str.c_str(), needed);
    return XR_SUCCESS;
}

std::string Runtime::GetPathString(XrPath path) const
{
    std::lock_guard lock(pathMutex_);
    auto it = pathToString_.find(path);
    if (it != pathToString_.end())
    {
        return it->second;
    }
    return {};
}
