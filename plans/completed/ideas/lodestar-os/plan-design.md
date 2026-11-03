# LODESTAR DESIGN OS — IMPLEMENTATION PLAN

> **Idea plan, rated.** Rated in `plans/active/skill-harvest.md`
> (2026-11-03, ideas 36-47): build no Core or Engineering OS as software;
> design work uses tried third-party skills plus a thin Lodestar bridge.

> Parent: plan.md  
> Dependency: Lodestar Core  
> Priority: P2  
> Initial agent: Claude Code

## 1. Objective

Build a Design Intelligence Engine that enables AI agents to perform professional product design and UX/UI work.

The system must improve:
- Product understanding.
- User-centered design decisions.
- Information architecture.
- Interaction quality.
- Visual consistency.
- Design system compliance.
- Accessibility.
- Design-to-development handoff.

Design OS must not be reduced to a UI generator.

## 2. Product & UX Knowledge

Build a structured knowledge base covering:

### Product thinking
- Problem framing.
- User needs.
- Business goals.
- Product requirements.
- Prioritization.
- Product trade-offs.
- Success metrics.

### UX research
- User interviews.
- User personas.
- Jobs to Be Done.
- User journeys.
- Pain points.
- Usability testing.
- Research synthesis.

### Information Architecture
- Navigation.
- Content hierarchy.
- Information grouping.
- User flows.
- Task flows.
- Search and discovery.

### Interaction Design
- Interaction patterns.
- Feedback states.
- Empty states.
- Loading states.
- Error states.
- Form behavior.
- Responsive behavior.

### Visual Design
- Typography.
- Color theory.
- Spacing.
- Grid systems.
- Visual hierarchy.
- Composition.
- Density.
- Contrast.
- Visual consistency.

### Accessibility
- WCAG principles.
- Keyboard navigation.
- Screen readers.
- Focus management.
- Color contrast.
- Semantic structure.

Requirements:
- Knowledge must explain context and trade-offs.
- Avoid universal design rules without context.
- Distinguish evidence-based UX recommendations from subjective design preferences.

## 3. Product Understanding Engine

Before designing, understand:

- Product purpose.
- Target users.
- Business objectives.
- User problems.
- Existing product behavior.
- Platform constraints.
- Existing design language.

Produce:
- Product brief.
- User and stakeholder assumptions.
- Problem statement.
- Key user journeys.
- Functional requirements.
- Design constraints.

Rules:
- Do not invent user research findings.
- Clearly label assumptions.
- Request clarification when missing information materially affects design.
- Do not confuse stakeholder preference with validated user needs.

## 4. UX Design Engine

Capabilities:
- Define user journeys.
- Build task flows.
- Design navigation.
- Structure information.
- Identify usability problems.
- Evaluate interaction patterns.
- Define content hierarchy.
- Recommend UX improvements.

Outputs:
- User flows.
- Information architecture.
- UX specifications.
- Interaction requirements.
- Edge-case documentation.

Validation:
- User tasks can be completed.
- Navigation is understandable.
- Important states are covered.
- Interactions are consistent.
- Accessibility is considered.

## 5. Design System Intelligence

Objective: Help AI understand and use the design system of each project.

Support:

### Design tokens
- Colors.
- Typography.
- Spacing.
- Radius.
- Shadows.
- Borders.
- Breakpoints.
- Motion.

### Components
- Component definitions.
- Variants.
- Properties.
- States.
- Composition rules.
- Usage guidelines.
- Accessibility behavior.

### Patterns
- Navigation.
- Forms.
- Tables.
- Dashboards.
- Modals.
- Notifications.
- Data visualization.
- Responsive layouts.

Requirements:
- Discover existing design assets before creating new ones.
- Treat existing project design systems as authoritative unless explicitly approved otherwise.
- Avoid creating duplicate components.
- Detect inconsistent token usage.
- Support versioned design system references.
- Explain when an existing component is unsuitable.

## 6. Design System Adapter

Provide a common interface for different design sources.

Potential integrations:
- Figma.
- CSS variables.
- Tailwind configuration.
- Component libraries.
- Storybook.
- Design token files.
- Project documentation.

The adapter should normalize design information into a common representation.

Do not make Figma mandatory for the MVP.

Do not assume every project has a formal design system.

Acceptance:
- The system can discover and interpret an existing project's tokens and component documentation.
- Missing design system information is explicitly identified.
- Design OS can work with projects that only have code-based UI libraries.

## 7. UI Design Engine

Objective: Translate product and UX requirements into coherent interfaces.

Workflow:

Understand → Structure → Explore → Design → Validate → Handoff.

Design considerations:
- Visual hierarchy.
- Layout.
- Typography.
- Color.
- Spacing.
- Component selection.
- Information density.
- Responsive behavior.
- Interaction states.
- Content quality.

Support:
- Wireframes.
- High-fidelity UI.
- Responsive layouts.
- Component specifications.
- Interaction specifications.
- Design alternatives.

Rules:
- Avoid generic AI-generated aesthetics.
- Avoid unnecessary gradients, shadows and decorative elements.
- Prioritize clarity and usability over visual novelty.
- Preserve the project's established design language.
- Explain meaningful design decisions.

## 8. Design Execution & Tool Integration

Initial execution environment:
- Claude Code.

Potential tools:
- Figma MCP or supported Figma integration.
- Browser automation.
- Screenshot capture.
- Existing frontend component libraries.
- Local design token files.

Requirements:
- Separate design reasoning from tool-specific execution.
- Use adapters for external tools.
- Validate tool capabilities before depending on them.
- Do not assume an agent can edit Figma merely because it can read Figma data.

## 9. Design Quality Engine

Create modular, measurable validation rules.

### Design System Compliance
- Token compliance.
- Approved component usage.
- Component variants.
- Typography rules.
- Spacing consistency.

### Visual Quality
- Visual hierarchy.
- Alignment.
- Density.
- Contrast.
- Consistency.
- Layout balance.

### UX Quality
- Task completion.
- Navigation clarity.
- Interaction feedback.
- Error prevention.
- Empty and loading states.

### Responsive Quality
- Overflow.
- Breakpoint behavior.
- Content adaptation.
- Touch target sizing.
- Layout stability.

### Accessibility
- Semantic elements.
- Keyboard access.
- Focus visibility.
- Contrast.
- Accessible labels.

Important:
Not every visual or UX criterion can be deterministically evaluated.

Classify checks as:
1. Deterministic: machine-verifiable.
2. Heuristic: rule-based recommendations.
3. Expert review: human or AI qualitative assessment.

Never represent subjective AI review as objective proof.

## 10. Visual QA Engine

Objective: Validate implemented UI against design specifications.

Capabilities:
- Capture browser screenshots.
- Compare expected and actual layout.
- Identify spacing inconsistencies.
- Identify missing or incorrect components.
- Detect responsive issues.
- Detect visual regressions.

Requirements:
- Support project-specific viewport sizes.
- Record screenshots and findings.
- Separate visual differences from functional failures.
- Avoid blocking delivery for insignificant rendering differences.
- Require human review for ambiguous visual findings.

## 11. Design-to-Engineering Handoff

Define a versioned handoff contract.

Required information:
- Product requirements.
- User flow.
- Screen definitions.
- Component references.
- Design tokens.
- Layout constraints.
- Responsive rules.
- Interaction states.
- Validation criteria.
- Known limitations.

Engineering OS must be able to consume this specification without relying only on screenshots or conversational context.

Support feedback in the reverse direction:
- Technical constraints.
- Component limitations.
- Performance constraints.
- Implementation alternatives.

Changes to an approved handoff must be versioned.

## 12. Design Workflows

### Product Discovery
Problem → Users → Research → Insights → Requirements.

### UX Design
Requirements → User Flow → Information Architecture → Interaction Specification → Review.

### UI Design
Design System Discovery → Layout → Components → Visual Design → Responsive Review.

### Design System Audit
Discover → Inventory → Analyze → Detect Inconsistency → Recommend Changes.

### Design QA
Specification → Capture → Validate → Findings → Remediation → Recheck.

### Design-to-Code
Approved Design → Handoff → Engineering Implementation → Visual QA → Joint Approval.

## 13. Skills Architecture

Suggested categories:

- design/product-thinking/
- design/research/
- design/information-architecture/
- design/ux/
- design/interaction/
- design/visual-design/
- design/design-system/
- design/accessibility/
- design/visual-qa/
- design/handoff/

Each skill must include:
- Purpose.
- Trigger conditions.
- Required inputs.
- Knowledge references.
- Execution steps.
- Quality criteria.
- Expected outputs.

## 14. Implementation sequence

DESIGN-01: Design knowledge architecture.

DESIGN-02: Product understanding and UX context.

DESIGN-03: Design system discovery.

DESIGN-04: Design token and component intelligence.

DESIGN-05: UX workflow.

DESIGN-06: UI design workflow.

DESIGN-07: Responsive and accessibility validation.

DESIGN-08: Design quality engine.

DESIGN-09: Visual QA.

DESIGN-10: Figma and external tool adapters.

DESIGN-11: Design-to-Engineering handoff.

DESIGN-12: End-to-end validation.

## 15. Design MVP acceptance

Given an existing product and a design request, Design OS must:

1. Understand product context.
2. Identify target users and requirements.
3. Discover existing design assets.
4. Define UX and interaction requirements.
5. Produce a structured UI specification.
6. Follow the project's design system.
7. Validate accessibility and responsive behavior.
8. Produce a handoff package.
9. Record design decisions.
10. Report assumptions and validation limitations.

Design OS must not claim that a design is user-validated unless actual user research or testing supports that claim.