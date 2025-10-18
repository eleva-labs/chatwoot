/**
 * Transforms a StageGraph workflow from AI Backend to Vue Flow format
 * @param {Object} workflow - Workflow object from API
 * @returns {Object} - Object with nodes and edges arrays
 */
export function transformStageGraphToVueFlow(workflow) {
  if (!workflow?.data?.stages) {
    return { nodes: [], edges: [] };
  }

  const stages = workflow.data.stages;
  const layoutData = workflow.layoutData || {};
  const nodeLayouts = layoutData.nodes || {};

  // Build a simple hierarchical layout based on connections
  // Calculate depth for each node (how far from start)
  const nodeDepths = {};
  const calculateDepth = (nodeId, depth = 0, visited = new Set()) => {
    if (visited.has(nodeId)) return;
    visited.add(nodeId);

    nodeDepths[nodeId] = Math.max(nodeDepths[nodeId] || 0, depth);

    const stage = stages.find(s => s.id === nodeId);
    if (stage?.transitions) {
      stage.transitions.forEach(t => {
        calculateDepth(t.target, depth + 1, visited);
      });
    }
  };

  calculateDepth('start');

  // Count nodes at each depth level
  const depthCounts = {};
  Object.entries(nodeDepths).forEach(([, depth]) => {
    depthCounts[depth] = (depthCounts[depth] || 0) + 1;
  });

  // Track position within each depth level
  const depthPositions = {};

  // Transform stages to nodes with hierarchical layout
  const nodes = stages.map(stage => {
    const layout = nodeLayouts[stage.id] || {};

    // Calculate position based on depth (hierarchical layout)
    const depth = nodeDepths[stage.id] || 0;
    const positionInDepth = depthPositions[depth] || 0;
    depthPositions[depth] = positionInDepth + 1;

    const nodesAtThisDepth = depthCounts[depth] || 1;

    // Horizontal spacing (left to right flow)
    const x = layout.x || depth * 400;

    // Vertical spacing - center nodes at each level
    const verticalSpacing = 180;
    const totalHeight = (nodesAtThisDepth - 1) * verticalSpacing;
    const startY = -totalHeight / 2;
    const y = layout.y || startY + positionInDepth * verticalSpacing;

    return {
      id: stage.id,
      type: 'default',
      position: { x, y },
      label: stage.name, // Vue Flow uses 'label' at the top level, not in data
      data: {
        label: stage.name, // Also keep it in data for compatibility
        description: stage.description || '',
      },
    };
  });

  // Transform transitions to edges
  const edges = stages.flatMap(stage => {
    if (!stage.transitions || stage.transitions.length === 0) {
      return [];
    }

    return stage.transitions.map(transition => ({
      id: `${stage.id}-${transition.target}`,
      source: stage.id,
      target: transition.target,
      label: transition.condition || '',
      type: 'default',
    }));
  });

  return { nodes, edges };
}

/**
 * Checks if workflow has valid data for rendering
 * @param {Object} workflow - Workflow object
 * @returns {boolean}
 */
export function isValidWorkflow(workflow) {
  return !!(
    workflow &&
    workflow.data &&
    workflow.data.stages &&
    Array.isArray(workflow.data.stages) &&
    workflow.data.stages.length > 0
  );
}
