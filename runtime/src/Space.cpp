// SPDX-License-Identifier: MPL-2.0

#include "Space.h"
#include "Session.h"
#include "Runtime.h"
#include "InputManager.h"
#include "ActionSet.h"
#include <glm/glm.hpp>
#include <glm/gtc/quaternion.hpp>

Space::Space(Session* session, Type type, XrReferenceSpaceType refType, const XrPosef& poseInSpace)
    : session_(session), type_(type), referenceSpaceType_(refType), poseInSpace_(poseInSpace)
{
    Runtime::Get().RegisterHandle(handle_, this);
}

Space::Space(Session* session, XrAction action, XrPath subactionPath, const XrPosef& poseInSpace)
    : session_(session), type_(Type::Action), poseInSpace_(poseInSpace), action_(action), subactionPath_(subactionPath)
{
    Runtime::Get().RegisterHandle(handle_, this);
}

Space::~Space()
{
    Runtime::Get().RemoveHandle(handle_);
}

static glm::quat ToGlm(const XrQuaternionf& q)
{
    return glm::quat(q.w, q.x, q.y, q.z);
}

static glm::vec3 ToGlm(const XrVector3f& v)
{
    return glm::vec3(v.x, v.y, v.z);
}

static XrQuaternionf ToXr(const glm::quat& q)
{
    return {q.x, q.y, q.z, q.w};
}

static XrVector3f ToXr(const glm::vec3& v)
{
    return {v.x, v.y, v.z};
}

static XrSpaceVelocity* FindSpaceVelocity(void* next)
{
    auto* current = reinterpret_cast<XrBaseOutStructure*>(next);
    while (current != nullptr)
    {
        if (current->type == XR_TYPE_SPACE_VELOCITY)
        {
            return reinterpret_cast<XrSpaceVelocity*>(current);
        }
        current = current->next;
    }
    return nullptr;
}

static InputManager::Hand HandFromPath(XrPath subactionPath)
{
    std::string pathStr = Runtime::Get().GetPathString(subactionPath);
    if (pathStr.find("right") != std::string::npos)
    {
        return InputManager::Hand::Right;
    }
    return InputManager::Hand::Left;
}

static InputManager::Hand HandFromBindingPath(const std::string& bindingPath)
{
    if (bindingPath.find("/user/hand/right") != std::string::npos)
    {
        return InputManager::Hand::Right;
    }
    return InputManager::Hand::Left;
}

static std::string ComponentFromBindingPath(const std::string& bindingPath)
{
    size_t inputPos = bindingPath.find("/input/");
    if (inputPos == std::string::npos)
    {
        return "";
    }
    return bindingPath.substr(inputPos + 7);
}

// Compute world pose of a space
static XrPosef GetWorldPose(Space* space, const InputManager& inputManager)
{
    XrPosef worldPose{};
    worldPose.orientation = {0, 0, 0, 1};
    worldPose.position = {0, 0, 0};

    if (space->GetType() == Space::Type::Reference)
    {
        switch (space->GetReferenceSpaceType())
        {
            case XR_REFERENCE_SPACE_TYPE_VIEW:
                worldPose = inputManager.GetHeadPose();
                break;
            case XR_REFERENCE_SPACE_TYPE_LOCAL:
            case XR_REFERENCE_SPACE_TYPE_LOCAL_FLOOR:
            case XR_REFERENCE_SPACE_TYPE_STAGE:
                // Identity — world origin
                break;
            default:
                break;
        }
    }
    else if (space->GetType() == Space::Type::Action)
    {
        auto* action = Runtime::Get().FromHandle<ActionState>(
            reinterpret_cast<uint64_t>(space->GetAction()));
        std::string poseBindingPath;

        if (action != nullptr)
        {
            const auto& data = action->GetSubactionData(space->GetSubactionPath());
            poseBindingPath = Runtime::Get().GetPathString(data.poseSourcePath);

            if (poseBindingPath.empty())
            {
                const auto& fallbackData = action->GetSubactionData(XR_NULL_PATH);
                poseBindingPath = Runtime::Get().GetPathString(fallbackData.poseSourcePath);
            }
        }

        if (!poseBindingPath.empty())
        {
            InputManager::Hand hand = HandFromBindingPath(poseBindingPath);
            worldPose = inputManager.GetPoseComponent(hand, ComponentFromBindingPath(poseBindingPath));
        }
        else
        {
            InputManager::Hand hand = HandFromPath(space->GetSubactionPath());
            worldPose = inputManager.GetControllerPose(hand);
        }
    }

    // Apply the space's offset pose
    const XrPosef& offset = space->GetPoseInSpace();
    glm::quat worldRot = ToGlm(worldPose.orientation);
    glm::vec3 worldPos = ToGlm(worldPose.position);
    glm::quat offsetRot = ToGlm(offset.orientation);
    glm::vec3 offsetPos = ToGlm(offset.position);

    glm::quat finalRot = worldRot * offsetRot;
    glm::vec3 finalPos = worldPos + worldRot * offsetPos;

    worldPose.orientation = ToXr(finalRot);
    worldPose.position = ToXr(finalPos);
    return worldPose;
}

XrResult Space::LocateSpace(Space* baseSpace, XrTime time, XrSpaceLocation* location)
{
    if (location == nullptr || baseSpace == nullptr)
    {
        return XR_ERROR_VALIDATION_FAILURE;
    }
    if (time <= 0)
    {
        return XR_ERROR_TIME_INVALID;
    }
    if (baseSpace->GetSession() != session_)
    {
        return XR_ERROR_HANDLE_INVALID;
    }

    const InputManager& inputManager = session_->GetInputManager();

    // Get world poses for both spaces
    XrPosef thisPose = GetWorldPose(this, inputManager);
    XrPosef basePose = GetWorldPose(baseSpace, inputManager);

    // Compute relative pose: this relative to base
    glm::quat baseRotInv = glm::inverse(ToGlm(basePose.orientation));
    glm::vec3 basePos = ToGlm(basePose.position);
    glm::vec3 thisPos = ToGlm(thisPose.position);
    glm::quat thisRot = ToGlm(thisPose.orientation);

    glm::quat relRot = baseRotInv * thisRot;
    glm::vec3 relPos = baseRotInv * (thisPos - basePos);

    location->type = XR_TYPE_SPACE_LOCATION;
    location->locationFlags = XR_SPACE_LOCATION_ORIENTATION_VALID_BIT | XR_SPACE_LOCATION_POSITION_VALID_BIT |
                              XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT | XR_SPACE_LOCATION_POSITION_TRACKED_BIT;
    location->pose.orientation = ToXr(relRot);
    location->pose.position = ToXr(relPos);

    if (XrSpaceVelocity* velocity = FindSpaceVelocity(location->next))
    {
        velocity->velocityFlags = 0;
        velocity->linearVelocity = {0.0f, 0.0f, 0.0f};
        velocity->angularVelocity = {0.0f, 0.0f, 0.0f};
    }

    return XR_SUCCESS;
}
