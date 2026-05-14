// SPDX-License-Identifier: MPL-2.0

#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>

#include "InputManager.h"
#include "TrackingReceiver.h"
#include <cmath>
#include <glm/gtc/quaternion.hpp>

using Catch::Matchers::WithinAbs;

TEST_CASE("InputManager — initial state", "[input]")
{
    InputManager im;

    SECTION("Head starts at default position")
    {
        XrPosef pose = im.GetHeadPose();
        CHECK_THAT(pose.position.x, WithinAbs(0.0, 0.001));
        CHECK_THAT(pose.position.y, WithinAbs(1.6, 0.001));
        CHECK_THAT(pose.position.z, WithinAbs(0.0, 0.001));
        // Identity orientation (no rotation)
        CHECK_THAT(pose.orientation.w, WithinAbs(1.0, 0.001));
    }

    SECTION("Controllers at default positions")
    {
        XrPosef left = im.GetControllerPose(InputManager::Hand::Left);
        CHECK_THAT(left.position.x, WithinAbs(-0.2, 0.001));
        CHECK_THAT(left.position.y, WithinAbs(1.3, 0.001));
        CHECK_THAT(left.position.z, WithinAbs(-0.4, 0.001));

        XrPosef right = im.GetControllerPose(InputManager::Hand::Right);
        CHECK_THAT(right.position.x, WithinAbs(0.2, 0.001));
        CHECK_THAT(right.position.y, WithinAbs(1.3, 0.001));
        CHECK_THAT(right.position.z, WithinAbs(-0.4, 0.001));
    }

    SECTION("Mode defaults to Controller")
    {
        CHECK(im.GetInputMode() == InputManager::InputMode::Controller);
    }

    SECTION("Buttons default to released")
    {
        CHECK(im.GetGrabValue(InputManager::Hand::Left) == 0.0f);
        CHECK(im.GetGrabValue(InputManager::Hand::Right) == 0.0f);
        CHECK(im.GetMenuClick() == false);
    }

    SECTION("Not streaming by default")
    {
        CHECK(im.IsStreaming() == false);
    }
}

TEST_CASE("InputManager — hand joint generation", "[input]")
{
    InputManager im;

    XrHandJointLocationEXT joints[XR_HAND_JOINT_COUNT_EXT] = {};
    im.GetHandJointLocations(InputManager::Hand::Left, joints, XR_HAND_JOINT_COUNT_EXT);

    SECTION("All 26 joints have valid flags")
    {
        for (uint32_t i = 0; i < XR_HAND_JOINT_COUNT_EXT; i++)
        {
            CHECK((joints[i].locationFlags & XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0);
            CHECK((joints[i].locationFlags & XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0);
        }
    }

    SECTION("All joints have positive radius")
    {
        for (uint32_t i = 0; i < XR_HAND_JOINT_COUNT_EXT; i++)
        {
            CHECK(joints[i].radius > 0.0f);
        }
    }

    SECTION("Palm is at controller position")
    {
        XrPosef ctrl = im.GetControllerPose(InputManager::Hand::Left);
        CHECK_THAT(joints[0].pose.position.x, WithinAbs(ctrl.position.x, 0.001));
        CHECK_THAT(joints[0].pose.position.y, WithinAbs(ctrl.position.y, 0.001));
        CHECK_THAT(joints[0].pose.position.z, WithinAbs(ctrl.position.z, 0.001));
    }
}

TEST_CASE("InputManager — eye views", "[input]")
{
    InputManager im;

    XrView views[2] = {};
    im.GetEyeViews(views, 2);

    SECTION("Two views with valid types")
    {
        CHECK(views[0].type == XR_TYPE_VIEW);
        CHECK(views[1].type == XR_TYPE_VIEW);
    }

    SECTION("Left eye is to the left of right eye")
    {
        CHECK(views[0].pose.position.x < views[1].pose.position.x);
    }

    SECTION("FOV is set")
    {
        CHECK(views[0].fov.angleLeft < 0.0f);
        CHECK(views[0].fov.angleRight > 0.0f);
        CHECK(views[0].fov.angleUp > 0.0f);
        CHECK(views[0].fov.angleDown < 0.0f);
    }
}

TEST_CASE("InputManager — streaming eye data", "[input]")
{
    InputManager im;
    TrackingReceiver receiver;
    im.SetTrackingReceiver(&receiver);

    oxr::protocol::TrackingPacket packet = {};
    packet.ipd = 0.070f;
    packet.eyeFov[0] = -1.10f;
    packet.eyeFov[1] = 0.90f;
    packet.eyeFov[2] = 1.00f;
    packet.eyeFov[3] = -0.95f;
    receiver.InjectPacket(reinterpret_cast<const uint8_t*>(&packet), sizeof(packet));

    im.Update(0.0f);

    XrView views[2] = {};
    im.GetEyeViews(views, 2);

    SECTION("Streaming IPD overrides the default eye separation")
    {
        CHECK_THAT(views[1].pose.position.x - views[0].pose.position.x, WithinAbs(0.070f, 0.001f));
    }

    SECTION("Streaming FOV is used for the left eye and mirrored for the right eye")
    {
        CHECK_THAT(views[0].fov.angleLeft, WithinAbs(-1.10f, 0.001f));
        CHECK_THAT(views[0].fov.angleRight, WithinAbs(0.90f, 0.001f));
        CHECK_THAT(views[0].fov.angleUp, WithinAbs(1.00f, 0.001f));
        CHECK_THAT(views[0].fov.angleDown, WithinAbs(-0.95f, 0.001f));

        CHECK_THAT(views[1].fov.angleLeft, WithinAbs(-0.90f, 0.001f));
        CHECK_THAT(views[1].fov.angleRight, WithinAbs(1.10f, 0.001f));
        CHECK_THAT(views[1].fov.angleUp, WithinAbs(1.00f, 0.001f));
        CHECK_THAT(views[1].fov.angleDown, WithinAbs(-0.95f, 0.001f));
    }
}

TEST_CASE("InputManager — streaming head pose", "[input]")
{
    InputManager im;
    TrackingReceiver receiver;
    im.SetTrackingReceiver(&receiver);

    oxr::protocol::TrackingPacket packet = {};
    packet.headPosition[0] = 1.0f;
    packet.headPosition[1] = 2.0f;
    packet.headPosition[2] = 3.0f;
    glm::quat yaw45 = glm::angleAxis(0.785f, glm::vec3(0.0f, 1.0f, 0.0f));
    packet.headOrientation[0] = yaw45.x;
    packet.headOrientation[1] = yaw45.y;
    packet.headOrientation[2] = yaw45.z;
    packet.headOrientation[3] = yaw45.w;
    receiver.InjectPacket(reinterpret_cast<const uint8_t*>(&packet), sizeof(packet));

    im.Update(0.0f);

    XrPosef pose = im.GetHeadPose();
    CHECK_THAT(pose.position.x, WithinAbs(1.0, 0.001));
    CHECK_THAT(pose.position.y, WithinAbs(2.0, 0.001));
    CHECK_THAT(pose.position.z, WithinAbs(3.0, 0.001));
    CHECK(std::abs(pose.orientation.y) > 0.01f);
}

TEST_CASE("TrackingReceiver — predicted pose extrapolates recent motion", "[input]")
{
    TrackingReceiver receiver;

    oxr::protocol::TrackingPacket first = {};
    first.timestampNs = 1'000'000'000;
    first.headPosition[0] = 0.000f;
    first.headOrientation[3] = 1.0f;

    oxr::protocol::TrackingPacket second = {};
    second.timestampNs = 1'011'111'111;
    second.headPosition[0] = 0.020f;
    glm::quat yaw10 = glm::angleAxis(0.1745f, glm::vec3(0.0f, 1.0f, 0.0f));
    second.headOrientation[0] = yaw10.x;
    second.headOrientation[1] = yaw10.y;
    second.headOrientation[2] = yaw10.z;
    second.headOrientation[3] = yaw10.w;

    receiver.InjectPacket(reinterpret_cast<const uint8_t*>(&first), sizeof(first));
    receiver.InjectPacket(reinterpret_cast<const uint8_t*>(&second), sizeof(second));
    receiver.SetPredictionHorizonMs(11.0f);

    oxr::protocol::TrackingPacket predicted = {};
    REQUIRE(receiver.GetPredictedPose(predicted));

    SECTION("Head position advances beyond the latest packet")
    {
        CHECK(predicted.headPosition[0] > second.headPosition[0]);
    }

    SECTION("Head orientation advances beyond the latest packet")
    {
        CHECK(std::abs(predicted.headOrientation[1]) > std::abs(second.headOrientation[1]));
    }
}

TEST_CASE("TrackingReceiver — angular velocity uses the full prediction horizon", "[input]")
{
    TrackingReceiver receiver;

    oxr::protocol::TrackingPacket first = {};
    first.timestampNs = 2'000'000'000;
    first.headOrientation[3] = 1.0f;

    oxr::protocol::TrackingPacket second = {};
    second.timestampNs = 2'011'111'111;
    second.headOrientation[3] = 1.0f;
    second.headAngularVelocity[1] = 1.0f;

    receiver.InjectPacket(reinterpret_cast<const uint8_t*>(&first), sizeof(first));
    receiver.InjectPacket(reinterpret_cast<const uint8_t*>(&second), sizeof(second));
    receiver.SetPredictionHorizonMs(20.0f);

    oxr::protocol::TrackingPacket predicted = {};
    REQUIRE(receiver.GetPredictedPose(predicted));

    CHECK_THAT(predicted.headOrientation[1], WithinAbs(std::sin(0.010f), 0.001f));
    CHECK_THAT(predicted.headOrientation[3], WithinAbs(std::cos(0.010f), 0.001f));
}
