# FS25_OpenTheGate

Open The Gate is a Farming Simulator 25 script mod that uses the normal vehicle horn to operate nearby animated gates and doors without leaving the vehicle.

## Controls

- **Two quick horn taps:** toggle the nearest compatible gate in the direction of travel. Closely paired entrance gates are operated together.
- **Hold the horn for 2 seconds:** toggle every compatible gate within 20 metres.

The ordinary horn sound continues to work normally. Attached implements and trailers are included when calculating the vehicle's front, rear, and search distance, and close gates are prioritised so large vehicles do not need precise positioning.

## Compatibility

Gate detection is behaviour-based rather than tied to specific object names. The mod supports standard animated placeable gates and doors, map-embedded animated entrances, and dynamically built fence gates that expose the normal FS25 `AnimatedObject` interaction interface.

## Support

Please report unsupported gates or doors through [GitHub Issues](https://github.com/bisdat/FS25_OpenTheGate/issues).

## Inspiration and provenance

Open The Gate is an independent implementation. The original horn-operated gate concept was inspired by the excellent **Honk To Open The Gates** mod by 50keda.

## License

The Open The Gate source code is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © 2026 bisdat.

Third-party trademarks, game assets, and other third-party material are not covered by this licence and remain the property of their respective owners.
