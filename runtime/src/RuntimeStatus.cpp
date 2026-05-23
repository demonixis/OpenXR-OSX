// SPDX-License-Identifier: MPL-2.0

#include "RuntimeStatus.h"
#include "Config.h"

#include <algorithm>
#include <chrono>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>
#include <unistd.h>

namespace
{

std::mutex& StatusMutex()
{
    static auto* mutex = new std::mutex();
    return *mutex;
}

std::string& ApplicationName()
{
    static auto* name = new std::string();
    return *name;
}

std::string JsonEscape(const std::string& value)
{
    std::ostringstream output;
    for (unsigned char character : value)
    {
        switch (character)
        {
            case '"':
                output << "\\\"";
                break;
            case '\\':
                output << "\\\\";
                break;
            case '\b':
                output << "\\b";
                break;
            case '\f':
                output << "\\f";
                break;
            case '\n':
                output << "\\n";
                break;
            case '\r':
                output << "\\r";
                break;
            case '\t':
                output << "\\t";
                break;
            default:
                if (character < 0x20)
                {
                    output << "\\u";
                    output << "00";
                    const char* hex = "0123456789abcdef";
                    output << hex[(character >> 4) & 0x0f];
                    output << hex[character & 0x0f];
                }
                else
                {
                    output << static_cast<char>(character);
                }
                break;
        }
    }
    return output.str();
}

std::string DeviceTypeForClientName(std::string clientName)
{
    std::transform(clientName.begin(), clientName.end(), clientName.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

    if (clientName.find("quest") != std::string::npos)
    {
        return "quest";
    }
    if (clientName.find("pico") != std::string::npos)
    {
        return "pico";
    }
    if (clientName.find("vision") != std::string::npos)
    {
        return "vision_pro";
    }
    if (clientName.find("simulator") != std::string::npos ||
        clientName.find("viewer") != std::string::npos)
    {
        return "simulator";
    }
    if (!clientName.empty())
    {
        return "unknown";
    }
    return "";
}

int64_t UnixTimeMilliseconds()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

void WriteStatusLocked(const std::string& state,
                       const std::string& transport,
                       const std::string& clientName)
{
    try
    {
        const Config& config = Config::Get();
        std::filesystem::create_directories(config.appSupportDir);

        const std::string deviceType = DeviceTypeForClientName(clientName);
        const std::string tempPath = config.runtimeStatusPath + ".tmp";

        std::ofstream file(tempPath, std::ios::trunc);
        if (!file.is_open())
        {
            return;
        }

        file << "{\n";
        file << "  \"state\": \"" << JsonEscape(state) << "\",\n";
        file << "  \"transport\": \"" << JsonEscape(transport) << "\",\n";
        file << "  \"device_type\": \"" << JsonEscape(deviceType) << "\",\n";
        file << "  \"client_name\": \"" << JsonEscape(clientName) << "\",\n";
        file << "  \"application_name\": \"" << JsonEscape(ApplicationName()) << "\",\n";
        file << "  \"process_id\": " << static_cast<long long>(getpid()) << ",\n";
        file << "  \"updated_at_unix_ms\": " << UnixTimeMilliseconds() << "\n";
        file << "}\n";
        file.close();

        std::filesystem::rename(tempPath, config.runtimeStatusPath);
    }
    catch (const std::exception& ex)
    {
        (void)ex;
    }
    catch (...)
    {
    }
}

} // namespace

void RuntimeStatus::SetApplicationName(const std::string& applicationName)
{
    std::lock_guard<std::mutex> lock(StatusMutex());
    ApplicationName() = applicationName;
    WriteStatusLocked("idle", "", "");
}

void RuntimeStatus::ClearApplicationName()
{
    std::lock_guard<std::mutex> lock(StatusMutex());
    ApplicationName().clear();
    WriteStatusLocked("idle", "", "");
}

void RuntimeStatus::SetIdle()
{
    std::lock_guard<std::mutex> lock(StatusMutex());
    WriteStatusLocked("idle", "", "");
}

void RuntimeStatus::SetStreaming(const std::string& transport, const std::string& clientName)
{
    std::lock_guard<std::mutex> lock(StatusMutex());
    WriteStatusLocked("streaming", transport, clientName);
}
