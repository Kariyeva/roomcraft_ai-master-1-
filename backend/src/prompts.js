function buildStrictPrompt(userPrompt, style) {
  const cleanPrompt = userPrompt.trim();

  const fallbackPrompt =
    "Make conservative interior edits while preserving the original room exactly.";

  const styleInstruction =
    style && style.trim() && style !== "interior design"
      ? `Apply ONLY the visual aesthetic of "${style}" to the requested object(s) only.`
      : "";

  return `
IMAGE EDITING TASK.

This is NOT a redesign.
This is NOT a redecoration.
This is NOT a room transformation.
This is NOT a creative reinterpretation.

You MUST preserve the uploaded room photo exactly.

USER REQUEST:
${cleanPrompt || fallbackPrompt}

STYLE:
${styleInstruction}

CRITICAL RULES:

1. ONLY modify the exact object(s) explicitly requested by the user.

2. EVERYTHING ELSE MUST REMAIN IDENTICAL:
- same walls
- same wall color
- same floor
- same carpet
- same lighting
- same shadows
- same brightness
- same exposure
- same curtains
- same window
- same decorations
- same shelves
- same table
- same plants
- same room layout
- same composition
- same camera angle
- same perspective
- same proportions
- same architecture

3. DO NOT beautify the room.
4. DO NOT improve the room unless explicitly requested.
5. DO NOT redesign the room.
6. DO NOT add extra furniture unless explicitly requested.
7. DO NOT remove objects unless explicitly requested.
8. DO NOT change room mood.
9. DO NOT change colors of unrelated objects.
10. Preserve photorealism.
11. Apply the SMALLEST precise edit necessary.

INTERPRETATION EXAMPLES:

If user says:
"make sofa red"
→ ONLY change sofa color to red

If user says:
"make sofa smaller"
→ ONLY reduce sofa size

If user says:
"replace sofa"
→ ONLY replace sofa

If user says:
"add plant"
→ ONLY add plant

If user says:
"change wall color"
→ ONLY change wall color

STRICTLY FOLLOW USER REQUEST ONLY.

FINAL COMMAND:
Generate a photorealistic edited version of the EXACT uploaded room photo with ONLY the requested modifications.
`;
}


module.exports = { buildStrictPrompt };
