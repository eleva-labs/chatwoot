# Research Process Guide

**Version**: 2.0.0
**Last Updated**: 2025-10-06
**Status**: Active
**Document Type**: Process Guide
**Project**: Chatwoot (Ruby on Rails + Vue.js)

---

## Table of Contents

1. [Overview](#overview)
2. [Research Agent Responsibilities](#research-agent-responsibilities)
3. [Research Process Workflow](#research-process-workflow)
4. [Phase 1: Request Understanding](#phase-1-request-understanding)
5. [Phase 2: Repository Analysis](#phase-2-repository-analysis)
6. [Phase 3: Solution Exploration](#phase-3-solution-exploration)
7. [Phase 4: Recommendation & Decision](#phase-4-recommendation--decision)
8. [Research Checklist](#research-checklist)
9. [Best Practices](#best-practices)
10. [Quick Reference](#quick-reference)
11. [Changelog](#changelog)

---

## Overview

The Research Process is the **critical first phase** before creating a design document. It ensures that:
1. The user's request is fully understood
2. The codebase and architecture are deeply analyzed
3. Multiple solution approaches are considered
4. The best approach is collaboratively selected
5. A solid foundation exists for the design phase

### Document Location

**IMPORTANT**: All research reports MUST be created in `/docs/ignored/design/`

- Research reports are NOT committed to the repository
- Templates remain in `/docs/processes/design/` for reference
- File naming: `/docs/ignored/design/<feature_name>_research.md`

### Key Principles

1. **Conversation First**: Research is collaborative, not automated
2. **Deep Understanding**: Use `@ultrathink` - read ALL relevant code
3. **Question Everything**: Challenge assumptions, ask clarifying questions
4. **Explore Alternatives**: Always present multiple approaches
5. **Align with Patterns**: Follow existing codebase conventions (Rails MVC + Services, Vue.js Composition API)
6. **Document Findings**: Create clear, actionable research reports
7. **Full-Stack Thinking**: Consider both backend and frontend implications
8. **Enterprise Compatibility**: Check Enterprise overlay compatibility

### Process Flow

```
User Request
    ↓
Phase 1: Request Understanding (Conversational)
    ├─ Parse request
    ├─ Ask clarifying questions
    └─ Define success criteria
    ↓
Phase 2: Repository Analysis (Deep Dive)
    ├─ Study Rails MVC + Services architecture
    ├─ Study Vue.js components and Vuex store
    ├─ Identify patterns
    ├─ Map dependencies (backend + frontend)
    ├─ Check Enterprise compatibility
    └─ Assess impact
    ↓
Phase 3: Solution Exploration (Creative)
    ├─ Generate alternatives
    ├─ Analyze pros/cons (full-stack)
    ├─ Discuss with user
    └─ Refine approaches
    ↓
Phase 4: Recommendation & Decision (Collaborative)
    ├─ Present recommendation
    ├─ Justify choice
    ├─ Get user approval
    └─ Create research report
    ↓
Proceed to Design Document
```

---

## Research Agent Responsibilities

### The Research Agent Must:

1. **Act as a Consultant** - Not just execute, but advise and guide
2. **Be Thorough** - Read ALL relevant code, don't make assumptions
3. **Be Conversational** - Engage the user, ask questions, discuss
4. **Be Critical** - Question the request if better approaches exist
5. **Be Comprehensive** - Consider all components (Models, Services, Controllers, Jobs, Frontend, i18n, Tests)
6. **Be Pattern-Aware** - Identify and follow Rails and Vue.js patterns
7. **Be Full-Stack** - Think about both backend and frontend implications
8. **Be Honest** - Admit uncertainty, ask for help when needed
9. **Document Everything** - Findings, conversations, decisions

### The Research Agent Should NOT:

1. **Jump to Implementation** - No code changes during research
2. **Make Unilateral Decisions** - Always collaborate with the user
3. **Skip Analysis** - Every request deserves deep investigation
4. **Ignore Alternatives** - Always present multiple options
5. **Assume Understanding** - Ask clarifying questions liberally
6. **Violate Architecture** - Respect Rails MVC + Services patterns
7. **Forget Frontend** - Backend changes often need frontend updates
8. **Skip Enterprise Checks** - Always verify Enterprise compatibility

---

## Research Process Workflow

### Duration: 30-90 minutes

### Input:
- User's feature request or problem statement
- Access to codebase

### Output:
- Research report with findings and recommendation
- User approval to proceed to design phase

---

## Phase 1: Request Understanding

**Goal**: Fully understand what the user wants to achieve

**Duration**: 10-20 minutes

### Step 1.1: Initial Request Parsing

**Actions**:
1. Read the user's request carefully
2. Identify the core objective
3. Note any mentioned constraints
4. Flag ambiguous or unclear points

**Example Questions to Ask Yourself**:
- What is the user trying to achieve?
- Is this a new feature, bug fix, refactoring, or optimization?
- Are there explicit requirements?
- Are there implicit requirements I should clarify?
- What is the scope? (API only? Full-stack? Database changes? Frontend UI?)

### Step 1.2: Clarification Questions

**Always Ask**:
- Scope clarification (backend only? frontend too? both?)
- Success criteria
- Constraints (timeline, backward compatibility, Enterprise compatibility, etc.)
- Context (why is this needed? what problem does it solve?)
- i18n requirements (UI labels? translations needed?)

**Example Conversation**:
```
User: "I want to add a priority field to the stores"

Agent: "I'd like to understand your request better:

1. What is the purpose of the priority field?
2. What values should it have? (numeric? enum like low/medium/high?)
3. Should it be exposed via the API?
4. Should it be optional or required?
5. Do we need to migrate existing stores (default value)?
6. Should it be visible in the UI? If so, where?
7. Do we need filtering/sorting by priority?
8. Are there any validation rules?
9. Should this work with the Enterprise edition?

Understanding these details will help me propose the best implementation approach."
```

### Step 1.3: Define Success Criteria

**Collaborate with User to Define**:
- What "done" looks like
- Acceptance criteria
- Performance requirements (if applicable)
- Testing expectations (RSpec + Vitest)
- Documentation needs
- i18n requirements (en.json + es.json)

**Document**:
```markdown
### Success Criteria
- [ ] Priority field added to Store model
- [ ] API returns priority in store responses
- [ ] UI displays priority badge
- [ ] Users can filter stores by priority
- [ ] All tests pass (backend + frontend)
- [ ] i18n translations added (en + es)
```

### Deliverable:
- Clear, unambiguous understanding of the request
- Documented success criteria
- User confirmation that you understand correctly

---

## Phase 2: Repository Analysis

**Goal**: Deeply understand the current codebase and architecture

**Duration**: 20-40 minutes

### Step 2.1: Identify Relevant Code

**Use Tools Extensively**:
```bash
# Find relevant files - Backend
Glob: "app/models/**/*store*.rb"
Glob: "app/services/**/*store*.rb"
Glob: "app/controllers/api/**/*store*.rb"

# Find relevant files - Frontend
Glob: "app/javascript/dashboard/components/**/*store*.vue"
Glob: "app/javascript/dashboard/store/modules/*store*.js"

# Search for patterns
Grep: "class Store"
Grep: "def create_store"
Grep: "store.priority"

# Read all relevant files
Read: /path/to/identified/file.rb
Read: /path/to/identified/file.vue
```

**Questions to Answer**:
- Where is the relevant code?
- What components are involved? (Models, Services, Controllers, Jobs, Listeners, Frontend, Vuex, i18n)
- What patterns are used?
- Are there similar features I can learn from?
- Is there Enterprise overlay code I need to check?

### Step 2.2: Study Architecture Patterns

**Read**:
1. CLAUDE.md - Project guidelines
2. ARCHITECTURE.md - System architecture
3. Related model files
4. Related service files
5. Related controller files
6. Related Vue component files
7. Related Vuex store files
8. Related i18n files (en.json, es.json)
9. Related test files (RSpec + Vitest)
10. Enterprise directory (if applicable)

**Analyze**:
- How are similar features implemented?
- What design patterns are used?
- How are models structured? (associations, validations, scopes, enums)
- How are service objects structured? (initialize + perform pattern)
- How are controllers structured? (strong parameters, error handling)
- How are Vue components structured? (Composition API, Tailwind CSS)
- How is Vuex store organized? (actions, mutations, getters)
- How is i18n managed? (en.json and es.json)
- How is event dispatching used? (dispatcher pattern)

### Step 2.3: Identify Dependencies & Impact

**Map Out**:
1. **Direct Dependencies** - What files import/use the affected code?
2. **Indirect Dependencies** - What features depend on this?
3. **Database Impact** - Schema changes needed? Migration strategy?
4. **API Impact** - Breaking changes? Versioning needed?
5. **Frontend Impact** - Vue components, Vuex store, API clients, i18n?
6. **Test Impact** - What tests need updates? (RSpec + Vitest)
7. **Enterprise Impact** - Enterprise overrides to check?

**Use Tools**:
```bash
# Find all references
Grep: "Store" -n --output-mode files_with_matches
Grep: "create_store" --output-mode files_with_matches

# Check test files
Glob: "spec/**/*store*.rb"
Glob: "app/javascript/dashboard/components/__tests__/*store*.spec.js"

# Check Enterprise
Glob: "enterprise/app/**/*store*.rb"
```

### Step 2.4: Review Similar Implementations

**Find Examples**:
- Look for similar features in the codebase
- Study how they were implemented
- Note patterns and conventions
- Learn from their design decisions

### Deliverable:
- Comprehensive understanding of current architecture
- List of affected files (backend + frontend)
- Identified patterns and conventions
- Impact assessment (database, API, frontend, tests, Enterprise)
- Examples of similar implementations

---

## Phase 3: Solution Exploration

**Goal**: Generate and evaluate multiple solution approaches

**Duration**: 15-30 minutes

### Step 3.1: Generate Alternative Approaches

**Always Create At Least 3 Alternatives**:

**Example Structure**:
```markdown
### Approach 1: Minimal Change (Simplest)
**Description**: [Brief description]

**Changes Required**:
- **Backend** (X files): [List key files]
- **Frontend** (X files): [List key files]

**Pros**:
- Quick to implement
- Low risk
- Backward compatible

**Cons**:
- Limited functionality
- No extensibility

**Effort**: X days
**Risk**: Low

---

### Approach 2: Proper Integration (Recommended)
**Description**: [Brief description]

**Changes Required**:
- **Backend** (X files): [List key files]
- **Frontend** (X files): [List key files]

**Pros**:
- Follows best practices
- Complete functionality
- Extensible

**Cons**:
- More work upfront

**Effort**: X days
**Risk**: Medium

---

### Approach 3: Complete System (Thorough)
**Description**: [Brief description]

**Changes Required**:
- **Backend** (X+ files): [List key files]
- **Frontend** (X+ files): [List key files]

**Pros**:
- Comprehensive solution
- Future-proof

**Cons**:
- High effort
- High complexity

**Effort**: X weeks
**Risk**: High
```

### Step 3.2: Analyze Trade-offs

**For Each Approach, Document**:
1. **Alignment with Architecture** - Follows Rails MVC + Services? Vue.js patterns?
2. **Complexity** - Implementation difficulty, files affected, risk level
3. **Maintainability** - Easy to understand? Easy to extend? Technical debt?
4. **Performance** - Database queries? API response time? Frontend rendering?
5. **Testing** - Testability? Coverage needed? (RSpec + Vitest)
6. **Migration** - Migration complexity? Rollback strategy? Backward compatibility?
7. **i18n** - Translations needed? Both en and es covered?

### Step 3.3: Discuss with User

**Present Alternatives**:
```markdown
I've analyzed your request and generated 3 potential approaches:

**Approach 1: Minimal Change**
- Quickest (1-2 days)
- Low risk
- But basic functionality only

**Approach 2: Proper Integration (My Recommendation)**
- Balanced effort (3-4 days)
- Follows Rails/Vue.js best practices
- Complete functionality
- Extensible

**Approach 3: Complete System**
- Most thorough (2-3 weeks)
- Comprehensive features
- But very high effort and risk

**My Recommendation**: Approach 2

**Rationale**:
1. Balances speed with quality
2. Follows existing patterns
3. Won't create technical debt
4. Manageable scope
5. Provides complete functionality

What do you think? Do you have timeline constraints or other considerations I should factor in?
```

### Step 3.4: Refine Based on Feedback

**Iterate**:
1. Listen to user's concerns
2. Adjust approaches based on feedback
3. Explore hybrid options if needed
4. Re-evaluate trade-offs
5. Converge on best approach

### Deliverable:
- 3+ alternative approaches documented
- Trade-off analysis for each (full-stack)
- User feedback incorporated
- Converged on preferred approach

---

## Phase 4: Recommendation & Decision

**Goal**: Make final recommendation and get user approval

**Duration**: 5-10 minutes

### Step 4.1: Present Final Recommendation

**Structure**:
```markdown
## Final Recommendation

### Chosen Approach: [Approach Name]

### Summary
[1-2 sentence summary of the approach]

### Why This Approach
1. **Reason 1** - [Explanation]
2. **Reason 2** - [Explanation]
3. **Reason 3** - [Explanation]

### What Will Be Changed

#### Backend (X files)
- **Models**: [List files and changes]
- **Services**: [List files and changes]
- **Controllers**: [List files and changes]
- **Migrations**: [List new migrations]
- **Tests**: [List test files]

#### Frontend (X files)
- **Components**: [List files and changes]
- **Vuex Store**: [List files and changes]
- **API Client**: [List files and changes]
- **i18n**: [List translation files]
- **Tests**: [List test files]

**Total Files**: X files (X backend + X frontend)

### Estimated Effort
- **Duration**: X days
- **Complexity**: Low | Medium | High
- **Risk**: Low | Medium | High

### Next Steps
1. Get your approval on this approach
2. Create detailed design document
3. Create execution plan
4. Begin implementation

### Risks & Mitigations
[List key risks and how to mitigate them]
```

### Step 4.2: Get User Approval

**Ask**:
```markdown
Does this approach look good to you?

- [ ] Yes, proceed to design document
- [ ] I have questions/concerns (please share)
- [ ] I prefer a different approach (which one?)
```

### Step 4.3: Create Research Report

**Once Approved, Document**:

Create file: `/docs/ignored/design/<feature_name>_research.md`

**Use Template**: See `RESEARCH_TEMPLATE.md`

**Include**:
1. Original request
2. Clarifications and assumptions
3. Architecture analysis findings (Rails + Vue.js)
4. Alternative approaches considered
5. Final recommendation
6. Trade-off justification
7. User approval timestamp
8. Next steps

### Deliverable:
- Final recommendation presented
- User approval obtained
- Research report created
- Ready to proceed to design phase

---

## Research Checklist

### Phase 1: Request Understanding ✅

- [ ] Read user request thoroughly
- [ ] Identified core objective
- [ ] Asked clarifying questions
- [ ] Defined success criteria (backend + frontend)
- [ ] Documented assumptions
- [ ] Confirmed i18n requirements
- [ ] Got user confirmation of understanding

### Phase 2: Repository Analysis ✅

- [ ] Used Glob to find relevant files (backend + frontend)
- [ ] Used Grep to search for patterns
- [ ] Read all relevant model files
- [ ] Read all relevant service files
- [ ] Read all relevant controller files
- [ ] Read all relevant Vue component files
- [ ] Read all relevant Vuex store files
- [ ] Read all relevant i18n files (en + es)
- [ ] Read all relevant test files (RSpec + Vitest)
- [ ] Read CLAUDE.md for project guidelines
- [ ] Read ARCHITECTURE.md for system overview
- [ ] Identified existing patterns (Rails + Vue.js)
- [ ] Mapped dependencies and impacts
- [ ] Assessed database impact (Rails migrations)
- [ ] Assessed API impact (Jbuilder, controllers)
- [ ] Assessed frontend impact (components, Vuex, i18n)
- [ ] Checked Enterprise compatibility
- [ ] Found similar implementations for reference

### Phase 3: Solution Exploration ✅

- [ ] Generated at least 3 alternative approaches
- [ ] Documented pros/cons for each approach (full-stack)
- [ ] Analyzed alignment with Rails MVC + Services architecture
- [ ] Estimated effort for each approach (backend + frontend)
- [ ] Assessed risk for each approach
- [ ] Presented alternatives to user
- [ ] Discussed trade-offs
- [ ] Incorporated user feedback
- [ ] Refined approaches based on feedback
- [ ] Converged on preferred approach

### Phase 4: Recommendation & Decision ✅

- [ ] Presented final recommendation
- [ ] Justified why this approach
- [ ] Documented what will change (backend + frontend)
- [ ] Estimated effort and risk
- [ ] Identified potential risks
- [ ] Defined mitigation strategies
- [ ] Got user approval
- [ ] Created research report
- [ ] Documented next steps

---

## Best Practices

### Communication

- **Be conversational and friendly** - Use clear, plain language
- **Ask questions liberally** - Don't make assumptions
- **Explain your reasoning** - Show your work with code examples and file paths
- **Admit when you're unsure** - Be honest about gaps in knowledge
- **Present options, not just answers** - Give users choices

### Analysis

- **Always use tools** - Don't rely on memory, read files and search thoroughly
- **Be systematic** - Follow phases in order, complete each checklist
- **Think full-stack** - Always consider both backend and frontend implications
- **Check Enterprise compatibility** - Always search `enterprise/` directory
- **Don't forget i18n** - Plan for both en.json and es.json

### Exploration

- **Present multiple approaches** - Always generate at least 3 alternatives
- **Be honest about trade-offs** - Don't push a single solution
- **Consider both backend and frontend** - Full-stack thinking required

### Decision Making

- **Respect the user** - Their time, input, and constraints are valuable
- **Stay in research mode** - Don't start implementing or writing design docs yet
- **Document everything** - Findings, conversations, decisions

### Decision Criteria

**Choose Minimal Approach When**:
- Timeline is very tight (< 2 days)
- Low complexity request
- Temporary solution acceptable
- No frontend UI needed

**Choose Proper Integration Approach When**:
- Moderate timeline (2-5 days available)
- Medium complexity
- Frontend UI required
- Follows existing patterns

**Choose Complete System Approach When**:
- Ample timeline (> 1 week)
- High complexity
- Long-term benefits justify cost
- Major architectural improvement

---

## Quick Reference

### Research Phase Timeline

| Phase | Duration | Focus |
|-------|----------|-------|
| 1. Request Understanding | 10-20 min | Clarify requirements (backend + frontend) |
| 2. Repository Analysis | 20-40 min | Understand codebase (Rails + Vue.js) |
| 3. Solution Exploration | 15-30 min | Generate alternatives (full-stack) |
| 4. Recommendation | 5-10 min | Document & approve |
| **Total** | **50-90 min** | **Research complete** |

### Common Search Patterns

```bash
# Find models
Glob: "app/models/**/*{entity_name}*.rb"
Grep: "class {EntityName}"

# Find services
Glob: "app/services/**/*{feature}*.rb"
Grep: "class {Feature}Service"

# Find controllers
Glob: "app/controllers/api/**/*{resource}*.rb"

# Find Vue components
Glob: "app/javascript/dashboard/components/**/*{feature}*.vue"

# Find Vuex stores
Glob: "app/javascript/dashboard/store/modules/*{resource}*.js"

# Find i18n
Glob: "app/javascript/dashboard/i18n/locale/{en,es}.json"

# Find tests - Backend
Glob: "spec/**/*{entity}*.rb"

# Find tests - Frontend
Glob: "app/javascript/dashboard/**/__tests__/**/*{component}*.spec.js"

# Check Enterprise
Glob: "enterprise/app/**/*{entity}*.rb"
```

### Questions to Always Ask

**Scope Questions**:
- "What is the purpose of this change?"
- "Should this be exposed via the API?"
- "Should this have a UI component?"
- "Are there backward compatibility requirements?"

**Technical Questions**:
- "Should this be optional or required?"
- "What validation rules apply?"
- "Do we need to migrate existing data?"
- "Should this dispatch events?"

**Frontend Questions**:
- "Where in the UI should this appear?"
- "Do we need filtering/sorting?"
- "What i18n translations are needed?"
- "Should this update Vuex store?"

**Timeline Questions**:
- "What is the timeline/urgency?"
- "Are there any constraints I should know about?"

**Enterprise Questions**:
- "Does this need to work with Enterprise edition?"
- "Are there Enterprise overrides to check?"

### Related Documentation

- **Research Template**: [RESEARCH_TEMPLATE.md](./RESEARCH_TEMPLATE.md) - Template for research reports
- **Design Template**: [DESIGN_TEMPLATE.md](./DESIGN_TEMPLATE.md) - Next phase after research
- **Development Process**: [../development/development_process.md](../development/development_process.md) - Implementation guide
- **Troubleshooting Guide**: [../troubleshooting.md](../troubleshooting.md) - Common research issues
- **Architecture**: [../../ARCHITECTURE.md](../../ARCHITECTURE.md) - System architecture
- **Guidelines**: [../../CLAUDE.md](../../CLAUDE.md) - Coding standards

---

## Changelog

### Version 2.0.0 (2025-10-06)
- **Major Update**: Adapted for Chatwoot (Rails + Vue.js) from Python/FastAPI
- Updated all references from Clean Architecture to Rails MVC + Services
- Added full-stack analysis requirements (backend + frontend)
- Updated search patterns for Rails and Vue.js files
- Added Enterprise compatibility checks throughout
- Updated code examples to Ruby and Vue.js
- Added i18n requirements (en.json + es.json)
- Updated testing sections (RSpec + Vitest)
- Added Vuex store and frontend component considerations

### Version 1.0.0 (2025-10-04)
- Initial version (Python/FastAPI)
- Defined 4-phase research process
- Created conversation guidelines
- Established research checklist

---

## Document Metadata

**Document Owner**: Development Team
**Maintained By**: Claude Code + Human Engineers
**Review Cycle**: Quarterly or as needed
**Last Reviewed**: 2025-10-06
**Next Review Due**: 2026-01-06
**Technology Stack**: Ruby on Rails 7.1+ | Vue.js 3 | PostgreSQL | Redis | Tailwind CSS
