# Lighting Concept AR

Lighting Concept AR is a native iPhone proof of concept for beginner drawing learners. It uses SwiftUI, ARKit, and RealityKit to place a simple virtual object on a detected horizontal surface, move virtual lights around it, and explain why the cast shadow changes.

## Supported Tooling

- Xcode checked on this machine: 26.6
- Swift checked on this machine: 6.3.3
- iPhoneOS SDK checked on this machine: 26.5
- Deployment target in the project: iOS 26.5
- Frameworks: SwiftUI, ARKit, RealityKit, UIKit

AR must be tested on an ARKit-capable physical iPhone. The current project has automatic signing enabled but no development team selected, so choose your team in Signing & Capabilities before installing on a device.

## Running On iPhone

1. Open `lightingconcept.xcodeproj` in Xcode.
2. Select the `lightingconcept` target.
3. In Signing & Capabilities, choose a development team.
4. Connect an ARKit-capable iPhone and select it as the run destination.
5. Build and run.
6. Grant camera permission when prompted.

## How To Use

- Move the iPhone until a horizontal table or floor is detected.
- When the status says “Tap the surface to place an object,” tap the detected surface.
- Use the Object tab to switch between Cube and Sphere.
- Use Move Object mode, then tap or drag on the detected plane to reposition the object.
- Use Move Light mode, then drag on the plane to move the selected light horizontally.
- Use the Height, X Position, and Z Position sliders for precise light placement.
- Use the Light tab to switch Point or Spot light, change colour, intensity, direction, and beam spread.
- Add up to three lights. The selected light has a visible cyan selection marker.
- Use the Learn tab to show light direction, representative rays, projection lines, ground shadow direction, shadow labels, and the information panel.

## Shadow Receiver

RealityKit dynamic lights can cast shadows between virtual entities, but they do not cast directly onto physical camera pixels. This proof of concept uses a semi-transparent virtual receiver plane aligned with the detected horizontal AR placement plane.

Classification: semi-transparent approximation with genuine RealityKit dynamic shadowing on virtual content.

The camera feed remains visible behind the receiver plane as much as possible, but the receiver is still virtual geometry. For spotlights, `SpotLightComponent.Shadow` enables dynamic light shadows. `DynamicLightShadowComponent` and `GroundingShadowComponent` are applied where supported by the installed SDK. Grounding shadows are noted as a fallback because they are not affected by virtual light position.

RealityKit does not expose a general physical “transparent shadow catcher” for the live camera image in this implementation. It also does not provide a broad point-light shadow softness control here. Beam spread is implemented for spotlights with inner and outer cone angles, using learner wording: Focused, Medium, and Spread.

## Projection Line Calculation

Projection lines are educational geometry, separate from the rendered shadow. For a point or spot light:

1. Take the selected light position.
2. Choose representative object points. The cube uses its four top vertices.
3. Build a ray from the light through each object point.
4. Intersect that ray with the horizontal ground plane.
5. Draw a procedural line to the intersection point and clamp excessive distances.

The sphere uses simplified representative rays and labels. It does not attempt a mathematically exact sphere shadow silhouette in this first version.

## Shadow Labels

Physically rendered:

- Object shading from RealityKit lighting.
- Dynamic shadowing on the virtual receiver plane where supported.

Geometric calculations:

- Light direction arrow.
- Ground projection direction.
- Cube projection lines and projection points.
- Approximate shadow length from light height, object height, and horizontal distance.

Educational approximations:

- Light Side
- Shadow Side
- Terminator
- Core Shadow
- Highlight
- Reflected Light
- Cast Shadow label position
- Contact Shadow label position

The labels are intentionally placed as instructional callouts. They are not produced by image-based lighting classification.

## Performance

- Dynamic lights are limited to three, below RealityKit’s documented eight dynamic-light scene limit.
- Projection overlays use a small number of procedural cylinders and spheres.
- Overlay geometry is rebuilt only when scene state changes or toggles change.
- No external 3D assets or textures are loaded.
- Surface texture changing is intentionally out of scope.

## RealityKit Limitations

- Physical tables and floors are part of the camera image, so they cannot directly receive virtual shadows.
- Point lights illuminate the scene but do not expose the same spotlight shadow controls used here.
- Shadow softness is approximated through spotlight beam spread, not a physical area-light model.
- Labels are approximate teaching aids.

## Future Improvements

- Add a dedicated test target for the pure shadow geometry functions.
- Add better screen-facing 3D labels.
- Add UI selection for individual shadow concepts.
- Add a more sophisticated receiver plane or occlusion workflow if RealityKit exposes a better transparent receiver in a future SDK.
- Validate dynamic shadow appearance across multiple physical iPhone models.
