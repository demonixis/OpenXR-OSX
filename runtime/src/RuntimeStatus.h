// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <string>

class RuntimeStatus
{
public:
    static void SetApplicationName(const std::string& applicationName);
    static void ClearApplicationName();
    static void SetIdle();
    static void SetStreaming(const std::string& transport, const std::string& clientName);
};
