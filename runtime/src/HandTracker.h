// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <openxr/openxr.h>
#include <cstdint>

class Session;

class HandTracker
{
public:
    HandTracker(Session* session, XrHandEXT hand);
    ~HandTracker();

    uint64_t GetHandle() const
    {
        return handle_;
    }

    Session* GetSession() const
    {
        return session_;
    }

    XrHandEXT GetHand() const
    {
        return hand_;
    }

    XrResult LocateHandJoints(XrSpace baseSpace, XrTime time, XrHandJointLocationsEXT* locations);

private:
    uint64_t handle_ = 0;
    Session* session_;
    XrHandEXT hand_;
};
