# Man Versus Machine — Art Direction

Use this document as the visual source of truth for new sprites, effects, backgrounds, and promotional images. The game is a side-view 2D boss-fight game made in Godot 4.7.2. Its visual language should stay readable at a glance: compact pixel art, hard silhouettes, a dark machine-world backdrop, and a small set of bright colors reserved for the player and danger.

## Core direction

- **Mood:** tense arcade duel; a lone human confronting enormous industrial machines.
- **View:** side-on 2D profile. Keep characters upright and readable against a flat arena. Do not use isometric, top-down, or three-quarter perspective.
- **Shape language:** chunky rectangles, clipped corners, simple plates, clear joints, and a few deliberate points. Favor strong silhouettes over surface detail.
- **Rendering:** crisp pixel art with hard edges, flat color regions, and no anti-aliasing. Avoid soft gradients, painterly texture, blur, bloom, and realistic lighting.
- **Pixel unit:** build small forms in 2×2 pixel clusters. The player sprite target is exactly 24×44 pixels; retain that canvas size and use nearest-neighbor scaling in Godot.
- **Asset framing:** one subject per sprite, centered, full body visible, and tightly framed without cropping. Use genuine transparency for game sprites. Do not bake a shadow, floor, glow, border, label, or text into a sprite.

## Palette

These colors are taken from the current project and should anchor new art. Small value shifts are fine when needed to separate adjacent shapes; keep the overall palette restrained.

| Use | Color | Hex |
|---|---|---|
| Arena background | Deep blue-black | `#0E131C` |
| Floor and structure | Slate blue | `#2E3B52` |
| Human player accent | Bright cyan | `#2EB8EB` |
| Player health | Green teal | `#33D18F` |
| Boss health | Machine red | `#E63338` |
| Attack warning | Light signal red | `#FF5861` |
| Conveyor / worn metal accent | Rust amber | `#9E612B` |
| Bolt boss | Hot orange | `#EB6133` |
| Hopper boss | Brass yellow | `#E6AD2E` |
| Ripsaw boss | Oxide teal | `#38D1B8` |
| Bulwark boss | Cold steel blue | `#6B9EEB` |
| Regent boss | Deep crimson | `#DB2952` |

Use the arena background for negative space. Keep the human cyan distinct from boss accents. Reserve the light signal red for attack warnings and dangerous attacks so it remains an immediate gameplay cue.

## Characters

### Human player

- Read as a human wearing practical, compact combat clothing and a reinforced frame. The upgrades can add visible machine-like plates, but the silhouette should remain clearly human.
- Keep the head, torso, two arms, and two legs legible at 24×44. Use 2×2 pixel clusters for details; do not rely on tiny single-pixel decoration.
- Use dark gray and slate clothing, with cyan limited to a small number of readable accents. Keep face detail minimal.
- The player starts with a gun. The sword and gun are separate equipment visuals, so sprites should leave the hands and front of the body readable for a weapon overlay.
- Make the silhouette readable both facing left and right. Avoid direction-specific details that break when the sprite is flipped.

### Boss machines

- Every boss should have a distinct, memorable silhouette before color or detail is added.
- Keep their bodies heavier and wider than the human. Use a few large armor plates and unmistakable joints instead of dense mechanical linework.
- Preserve the existing stage accent colors in the palette table. Add dark steel shadows and small pale metal highlights, not a rainbow of extra colors.
- Attack shapes should match their gameplay: Bolt is a low, fast charge; Hopper uses low horizontal ripples; Ripsaw fires radial bullets; Bulwark sends tall shield walls; Regent combines fast radial attacks and crossing walls.

## Arenas and effects

- Arenas are broad, flat fighting spaces with a dark background, a solid floor, and little decoration. The boss fight has no traversal platforms.
- Keep decorative machinery near the edges and low contrast. Leave the center clear so players can read movement, hitboxes, and telegraphs.
- Boss attack warnings use a light-red shape around the boss for a short, readable beat. Red is gameplay information, not general trim.
- Projectiles and attack walls use solid silhouettes with a crisp outline or value contrast. A player should identify their path and danger against every stage background.
- Player movement dust is made of tiny gray squares from the feet. Particles scale and fade; keep their contrast low so they do not resemble attacks.
- Avoid full-screen flashes and large decorative particle clouds that obscure the boss or player.

## Interface

- The fight HUD follows a one-on-one fighting-game layout: player health at the upper left, boss health at the upper right, boss health numbers inside its bar, and names below the bars.
- Use the same deep background, slate structure, cyan player health, and red boss health colors defined above.
- Keep labels short and aligned. The arena HUD does not carry gear counts, control instructions, or unrelated status text.
- Draw interface text and health bars in Godot controls rather than baking them into generated images.

## Image-generation rules

For a game sprite, request a single transparent-background subject with the exact target canvas and a clean side profile. State that the artwork is pixel art built on a 2×2 pixel cluster grid, has no anti-aliasing, and uses the palette above. Ask for no text, no background, no extra subjects, and no baked shadows. Inspect the result at native size; simplify it if its silhouette or weapon is not readable at 24×44.

For a style reference sheet, show the human, five differently shaped machines, arena palette, warning red, and a few projectile shapes together as a labeled-free visual board. Keep a large swatch for each palette color and show the player at native scale. Save that board in the project and provide it as a visual reference for later generations.

### Reusable prompt

> Create a crisp pixel-art asset for a side-view 2D arcade boss fighter. Follow the project's `ART_STYLE.md`: use the dark blue-black and slate arena palette, cyan for the human, and only the relevant boss accent color. Use hard edges, flat color blocks, and forms built from 2×2 pixel clusters. Keep the silhouette simple and readable at the stated native size. Use a true transparent background for a game sprite. Show one centered subject in profile, fully inside the canvas. No text, no border, no scenery, no extra characters, no anti-aliasing, no gradients, no blur, and no baked shadow.

Append the specific subject, pose, native dimensions, and any required animation view after this prompt. When generating a set, reuse the same style reference image and palette instead of inventing a new style for each asset.
