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

  // Transform stages to nodes
  const nodes = stages.map(stage => {
    const layout = nodeLayouts[stage.id] || {};

    return {
      id: stage.id,
      type: 'default', // Use Vue Flow default node for POC
      position: {
        x: layout.x || 0,
        y: layout.y || 0,
      },
      data: {
        label: stage.name,
        description: stage.description || '',
      },
      style: {
        width: layout.width ? `${layout.width}px` : undefined,
        height: layout.height ? `${layout.height}px` : undefined,
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
