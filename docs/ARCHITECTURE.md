# Architecture

Apple Watch senses motion and runs the algorithms; the iPhone mirrors live numbers and stores history. Shared logic lives in the `AltusKit` Swift package.

```mermaid
flowchart LR
    subgraph Watch["AltusWatch (watchOS)"]
        CM[CoreMotionProvider<br/>accel + gyro]
        WS[WorkoutSessionManager<br/>HKWorkoutSession]
        WC[WatchConnectivityManager]
        UIW[Watch UI]
    end

    subgraph Kit["Packages/AltusKit (shared)"]
        Sig[SignalFilters]
        Jump[JumpDetector<br/>flight-time h = g·t²/8]
        Rep[RepDetector]
        Vel[VelocityIntegrator]
        RIR[RIREstimator]
        Pay["LiveMetricsPayload<br/>SessionEnvelope"]
        Mod[Models: JumpResult · RepResult]
    end

    subgraph Phone["AltusApp (iOS)"]
        PC[PhoneConnectivityManager]
        UIP[ContentView]
        SD[(SwiftData<br/>ModelContainer+Altus)]
    end

    CM --> Sig --> Jump
    Sig --> Rep --> Vel --> RIR
    WS -.keeps sensors alive.-> CM
    Jump --> Mod
    Vel --> Mod
    Mod --> Pay --> WC
    WC <-->|WatchConnectivity| PC
    PC --> UIP
    PC --> SD
    Mod --> UIW
```

Project generation is via XcodeGen (`project.yml`).
