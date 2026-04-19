# speckit.aide.requirements

Generate structured requirements from the project vision and user input.

## Usage

Invoke this command to create or update structured requirements for the current feature.

## Behavior

1. Read project vision from `.specify/memory/vision.md` (if available)
2. Read current feature spec from `specs/{feature}/spec.md` (if available)
3. Analyze inputs and generate structured requirements
4. Categorize requirements: functional, non-functional, constraints
5. Prioritize requirements (MoSCoW: Must/Should/Could/Won't)
6. Save requirements document
