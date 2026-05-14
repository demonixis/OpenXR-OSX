// SPDX-License-Identifier: MPL-2.0

#include <catch2/catch_test_macros.hpp>

#include "Protocol.h"

#include <cstddef>

using namespace oxr::protocol;

TEST_CASE("C++ protocol layouts match the documented wire format", "[protocol]")
{
    STATIC_REQUIRE(sizeof(ServerAnnounce) == 92);
    STATIC_REQUIRE(sizeof(ClientConnect) == 80);
    STATIC_REQUIRE(sizeof(VideoPacketHeader) == 24);

    STATIC_REQUIRE(sizeof(LatencyReport) == 20);
    STATIC_REQUIRE(sizeof(RequestKeyframe) == 12);
    STATIC_REQUIRE(sizeof(HapticsCommand) == 16);
    STATIC_REQUIRE(sizeof(NackRequest) == 24);

    STATIC_REQUIRE(sizeof(TrackingPacket) == 1008);
    STATIC_REQUIRE(offsetof(TrackingPacket, headLinearVelocity) == 152);
    STATIC_REQUIRE(offsetof(TrackingPacket, headAngularVelocity) == 164);
    STATIC_REQUIRE(offsetof(TrackingPacket, leftHandJoints) == 176);
    STATIC_REQUIRE(offsetof(TrackingPacket, rightHandJoints) == 592);
}
