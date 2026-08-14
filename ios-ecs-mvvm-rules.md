---
name: ios-ecs-mvvm-rules
description: Strict definitions and rules for RealityKit ECS architecture and SwiftUI MVVM integration on iOS.
---

# RealityKit ECS & SwiftUI MVVM Architecture Rules

When developing iOS applications that combine 3D/AR environments with standard user interfaces, strictly adhere to the following architectural boundaries and definitions.

## Framework & Architecture Boundaries

1.  **3D/AR Domain (ECS):** Strictly use **RealityKit** and **RealityView** for the Entity Component System implementation. All 3D objects, spatial logic, and rendering must exist within this paradigm.
2.  **App & UI Domain (MVVM):** Strictly use **SwiftUI** and the **MVVM (Model-View-ViewModel)** pattern for 2D interfaces, app-level state management, and business logic. The ViewModel acts as the bridge that manages the state driving the `RealityView`.

## Core RealityKit ECS Definitions

*   **Entity**: A generic container with a unique ID. It has **no data** and **no behavior**. It is just a blank canvas in 3D space.
*   **Component**: A lightweight struct attached to an Entity. It holds properties/state, but **no logic** (e.g., Position, Health).
*   **System**: Runs every frame (e.g., 60-120 FPS on iOS). It queries the 3D scene for Entities containing specific Components and performs calculations.

## Architectural Guidelines

*   **Strict Separation:** Never mix logic into Components or data into Systems. Systems are the *only* place where frame-by-frame calculations occur in RealityKit.
*   **Query-Based Grouping:** Because Entities are just "blank canvases," organize them dynamically by having Systems query the `RealityView` scene for specific Component combinations.
