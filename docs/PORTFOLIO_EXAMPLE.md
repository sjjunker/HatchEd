# What a Basic Portfolio Looks Like

In the app, a portfolio is shown in **Portfolio Detail**: a header card, optional remarks, then the main **Portfolio Content** (AI-generated markdown with images). Below is the **structure** and **example content** for a basic portfolio.

---

## 1. Screen layout (Portfolio Detail)

- **Header card**: Student name, design pattern (e.g. "General Portfolio"), created date.
- **Student Remarks** (if the parent entered any): Short block of text.
- **Instructor Remarks** (if any): Short block of text.
- **Portfolio Content**: One scrollable block with the full compiled markdown. In the current build this is plain text; images are loaded when you export to PDF (and could be rendered in-app later).

---

## 2. Example compiled content (markdown)

This is the kind of text the AI produces and that appears in "Portfolio Content". Image slots are marked as `[IMAGE: description]` (or a URL after processing); in the PDF they become actual images.

```markdown
# Jordan Smith - General Portfolio

This portfolio showcases the academic achievements and work of Jordan Smith.

## About Me

[IMAGE: Student photo or illustration]

Jordan is a dedicated student committed to academic excellence and personal growth. This portfolio represents their journey, achievements, and progress throughout the academic year.

## Student Remarks

Jordan has shown great improvement in math this term and enjoys science projects.

## Instructor Remarks

Strong participation and consistent effort. Recommended for honors next year.

## Achievements and Awards

[IMAGE: Awards or certificates]

- Honor Roll, Fall 2024
- Science Fair 2nd Place
- Perfect Attendance, Term 1

## Attendance

[IMAGE: Attendance chart or calendar]

- Classes Attended: 87
- Classes Missed: 2
- Attendance Rate: 97.8%
- Current Attendance Streak: 12 days

## Yearly Accomplishments by Subject

### Mathematics

[IMAGE: Work sample from Mathematics]

Grade: 92.5%

Completed 14 assignments in this course. Strong performance on algebra and word problems.

### English

[IMAGE: Work sample from English]

Grade: 88.0%

Completed 12 assignments. Excellent essay work and reading comprehension.

### Science

[IMAGE: Work sample from Science]

Grade: 95.0%

Completed 10 assignments. Outstanding lab reports and curiosity in life science.

## Extracurricular Activities

[IMAGE: Extracurricular activities]

- Soccer (fall)
- School band – trumpet
- Robotics club

## Report Card

[IMAGE: Report card visualization]

- Mathematics: 92.5%
- English: 88.0%
- Science: 95.0%

## Service Log

[IMAGE: Community service activities]

- Library volunteer: 8 hours
- Food drive organizer: 4 hours

## Summary

This portfolio represents the dedication and progress of Jordan Smith throughout their academic journey.
```

---

## 3. Section checklist (what the AI includes)

| Section | Content source |
|--------|----------------|
| **About Me** | Parent’s “About Me” text or AI-generated intro |
| **Student Remarks** | Parent-entered (optional) |
| **Instructor Remarks** | Parent-entered (optional) |
| **Achievements and Awards** | Parent text + AI enhancement |
| **Attendance** | From app attendance data + parent notes |
| **Yearly Accomplishments by Subject** | From courses/grades and assignments |
| **Extracurricular Activities** | Parent text or AI-generated |
| **Report Card** | From course grades in the app |
| **Service Log** | Parent text or AI-generated |
| **Summary** | Short AI closing |

Images appear where you see `[IMAGE: ...]` (or the replaced URL). When you tap **Export/Share**, the app generates a PDF and replaces those placeholders with the actual portfolio images (AI-generated and/or parent-provided photos).

---

## 4. Design patterns

Portfolios can use different **design patterns** (e.g. General, Academic, Creative). The same sections above are used; the AI tailors tone and style to the chosen pattern.

---

*This example is from the fallback template and AI prompt structure in `server/src/services/chatgptService.js`. Real portfolios will vary based on student data, parent input, and chosen design pattern.*
