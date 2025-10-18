import * as dagre from 'dagre';

/**
 * Transforms a StageGraph workflow from AI Backend to Vue Flow format
 * Uses Dagre for automatic hierarchical layout
 * @param {Object} workflow - Workflow object from API
 * @returns {Object} - Object with nodes and edges arrays
 */
export function transformStageGraphToVueFlow(workflow) {
  if (!workflow?.data?.stages) {
    return { nodes: [], edges: [] };
  }

  const stages = workflow.data.stages;

  // Create nodes first (positions will be calculated by Dagre)
  const nodes = stages.map(stage => ({
    id: stage.id,
    type: 'stageNode',
    position: { x: 0, y: 0 }, // Will be updated by Dagre
    data: {
      name: stage.name,
      description: stage.description || '',
      initialNode: stage.initial_node || false,
      requirements: stage.requirements || [],
    },
  }));

  // Transform transitions to edges
  const edges = stages.flatMap(stage => {
    if (!stage.transitions || stage.transitions.length === 0) {
      return [];
    }

    return stage.transitions.map(transition => ({
      id: `${stage.id}-${transition.target}`,
      source: stage.id,
      target: transition.target,
      sourceHandle: 'source-right', // Connect from source node's right handle
      targetHandle: 'target-left', // Connect to target node's left handle
      label: transition.condition || '',
      type: 'default',
      animated: !!transition.condition, // Animate edges with conditions
    }));
  });

  // Apply Dagre layout
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));
  dagreGraph.setGraph({
    rankdir: 'LR', // Left to right layout
    nodesep: 80, // Horizontal spacing between nodes
    ranksep: 150, // Vertical spacing between ranks
  });

  // Add nodes to Dagre graph
  nodes.forEach(node => {
    dagreGraph.setNode(node.id, {
      width: 280, // Node width
      height: 180, // Approximate node height
    });
  });

  // Add edges to Dagre graph
  edges.forEach(edge => {
    dagreGraph.setEdge(edge.source, edge.target);
  });

  // Calculate layout
  dagre.layout(dagreGraph);

  // Apply calculated positions to nodes
  const layoutedNodes = nodes.map(node => {
    const dagreNode = dagreGraph.node(node.id);
    return {
      ...node,
      position: {
        x: dagreNode.x - 140, // Center the node (width / 2)
        y: dagreNode.y - 90, // Center the node (height / 2)
      },
    };
  });

  return { nodes: layoutedNodes, edges };
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
