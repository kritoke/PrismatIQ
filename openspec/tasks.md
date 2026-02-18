### Phase 1: Infrastructure & Core Math

* [x] **Task 1.1:** Initialize the project.
* Create `shard.yml` with `naqvis/crimage` as a dependency.
* Setup the standard `src/` and `spec/` folder structure.


* [x] **Task 1.2:** Implement `PrismatIQ::Color`.
* Create a `struct` with `y, i, q` as `Float64`.
* Implement `self.from_rgb(r, g, b)` and `to_rgb`.
* **Test:** Write specs to ensure converting RGB -> YIQ -> RGB returns the original values (within a small rounding tolerance).



### Phase 2: The VBox & Histogram Logic

* [x] **Task 2.1:** Implement the `VBox` struct.
* Include properties for dimensions: `y1, y2, i1, i2, q1, q2`.
* Add methods for `volume`, `count`, and `priority`.


* [x] **Task 2.2:** Build the `Histogram` logic.
* Create a method to reduce the color space (e.g., 5-bit color) to keep the histogram memory-efficient.
* Iterate through a `CrImage` pixel buffer and populate the histogram.
* **Constraint:** Use the `quality` parameter to skip pixels as defined in the spec.



### Phase 3: The MMCQ Algorithm

* [x] **Task 3.1:** Implement the `split` logic.
* Inside `VBox`, create a method to find the longest axis (Y, I, or Q).
* Split the box at the median point of the color population along that axis.


* [x] **Task 3.2:** Implement the `Quantizer`.
* Use a `PriorityQueue` (or a sorted array) to manage VBoxes.
* Loop until the number of VBoxes equals the requested `color_count`.
* Extract the `average_color` from each final VBox.



### Phase 4: Public API & Refinement

* [x] **Task 4.1:** Create the main `PrismatIQ` module methods.
* `PrismatIQ.get_palette(path, count, quality)`
* `PrismatIQ.get_color(path)` (Helper for a palette of 1)


* [ ] **Task 4.2:** Performance Optimization.
* [ ] Verify no large arrays are being copied inside the pixel loop.
* [ ] Check that `Alpha` channels are being correctly ignored.
* [ ] Profile `get_palette` with large images to identify bottlenecks.
* [ ] Consider using `Slice` instead of `Hash` for histogram if profiling shows improvement.


* [ ] **Task 4.3:** Documentation.
* [ ] Generate `README.md` with usage examples.
* [ ] Add API documentation for all public methods.
* [ ] Create benchmark comparison vs other color extraction tools.
* [ ] Include example images showing palette extraction results.

---

## Change Management

Active change: `openspec/changes/optimization-and-docs/`
- Task 4.2: Performance optimization
- Task 4.3: Documentation
