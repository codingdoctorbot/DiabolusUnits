# DiabolicUI3 (Arahort Edition) artwork — staged for review

Source: CurseForge "DiabolicUI (Arahort Edition)", local download `~/Downloads/DiabolicUI3` (version 6.6.6-r499), checked 21 October 2026.

License: the CurseForge project's License field reads **Public Domain**. The same page credits "Artwork: Alex Arahort and Karina Kisenkova" and states the original DiabolicUI art by Lars "Goldpaw" Norberg is "Custom License (All Rights Reserved)". The GitHub repo (Arahort/diabolic) has no license file. The original DiabolicUI2 LICENSE.txt forbids sharing, modifying or distributing its art.

Selection rule: only files whose SHA-1 matches no file in DiabolicUI2 (reference copy) and whose name does not appear in DiabolicUI2 — i.e. new in the fork, covered by the fork's Public Domain label. Excluded:
- 45 files byte-identical to DiabolicUI2 (Goldpaw, All Rights Reserved).
- 7 files identical to existing DiabolusUnits media (already present).
- 9 `point_*.tga` class-power textures: names match Goldpaw's AzeriteUI and could not be checked locally.

Caveat: "new in the fork" is a byte and name comparison. A fork file could still be an edit of Goldpaw art; check visually before shipping, and credit Arahort and Karina Kisenkova in CREDITS.md when any file is used.

Update (same day): Goldpaw's original 2016 DiabolicUI (github.com/thExiled/DiabolicUI, commits by Lars Norberg, July 2016) is plain MIT with no artwork exclusion. Its 176 textures are staged in `../diabolicui2016/` with the license. Eight DiabolicUI3 files are byte-identical to it (chatbutton-maximize, blank, orb2, shade-circle ×2, micromenu-toggle, bar-small, minimap-mask-opaque), so those are MIT too. The 2022 DiabolicUI2 art restriction applies only to art first published after 2016.
