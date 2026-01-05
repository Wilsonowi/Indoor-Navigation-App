class Edge {
  final String to;
  final int distance; // in meters
  final String action;

  Edge(this.to, this.distance, this.action);
}

class IndoorNavigation {
  final Map<String, List<Edge>> graph = {};

  IndoorNavigation() {
    _buildGraph();
  }

  void _addEdge(String from, String to, int distance, String action) {
    graph.putIfAbsent(from, () => []).add(Edge(to, distance, action));
    graph.putIfAbsent(to, () => []); // ✅ ensure "to" node exists too
  }

  void _buildGraph() {
    // --- Top Row: N001 → N007 ---
    _addEdge("N001", "N002", 8, "Proceed straight");
    _addEdge("N002", "N001", 8, "Proceed straight back");

    _addEdge("N002", "N003", 8, "Proceed straight");
    _addEdge("N003", "N002", 8, "Proceed straight back");

    _addEdge("N003", "Exit", 8, "Proceed straight");
    _addEdge("N004", "Exit", 8, "Proceed straight");

    _addEdge("Exit", "N003", 8, "Proceed straight back");
    _addEdge("Exit", "N004", 8, "Proceed straight back");

    _addEdge("N004", "N005", 8, "Proceed straight");
    _addEdge("N005", "N004", 8, "Proceed straight back");

    _addEdge("N005", "N006", 8, "Proceed straight");
    _addEdge("N006", "N005", 8, "Proceed straight back");

    _addEdge("N006", "N007", 8, "Proceed straight");
    _addEdge("N007", "N006", 8, "Proceed straight back");

    // --- Bottom Row: N012 → N008 ---
    _addEdge("N012", "N011", 8, "Proceed straight");
    _addEdge("N011", "N012", 8, "Proceed straight back");

    _addEdge("N011", "N010", 8, "Proceed straight");
    _addEdge("N010", "N011", 8, "Proceed straight back");

    _addEdge("N010", "N009", 8, "Proceed straight");
    _addEdge("N009", "N010", 8, "Proceed straight back");

    _addEdge("N009", "Toilet", 8, "Proceed straight");
    _addEdge("N008", "Toilet", 8, "Proceed straight back");

    _addEdge("Toilet", "N009", 8, "Proceed straight");
    _addEdge("Toilet", "N008", 8, "Proceed straight back");

    // --- Vertical links (opposite rooms) ---
    _addEdge("N001", "N012", 10, "Turn Left");
    _addEdge("N012", "N001", 10, "Turn Right");

    _addEdge("N002", "N011", 10, "Turn Left");
    _addEdge("N011", "N002", 10, "Turn Right");

    _addEdge("N003", "N010", 10, "Turn Left");
    _addEdge("N010", "N003", 10, "Turn Right");

    _addEdge("N007", "N008", 10, "Turn Left");
    _addEdge("N008", "N007", 10, "Turn Right");
  }

  // -----------------------------
  // Dijkstra Shortest Path
  // -----------------------------
  List<String>? calculateRoute(String startInput, String endInput) {
    final start = startInput.trim().toUpperCase();
    final end = endInput.trim().toUpperCase();

    if (!graph.containsKey(start) || !graph.containsKey(end)) {
      print("Invalid nodes: start=$start, end=$end");
      return null;
    }

    final dist = <String, int>{};
    final prev = <String, String?>{};
    final unvisited = Set<String>.from(graph.keys);

    for (var node in graph.keys) {
      dist[node] = 1 << 30;
      prev[node] = null;
    }
    dist[start] = 0;

    while (unvisited.isNotEmpty) {
      final u = unvisited.reduce(
        (a, b) => (dist[a] ?? 1 << 30) < (dist[b] ?? 1 << 30) ? a : b,
      );
      unvisited.remove(u);

      if (u == end) break;

      for (var edge in graph[u]!) {
        final alt = (dist[u] ?? 1 << 30) + edge.distance;
        if (alt < (dist[edge.to] ?? 1 << 30)) {
          dist[edge.to] = alt;
          prev[edge.to] = u;
        }
      }
    }

    if (dist[end] == 1 << 30) return null;

    final path = <String>[];
    String? at = end;
    while (at != null) {
      path.add(at);
      at = prev[at];
    }
    return path.reversed.toList();
  }

  // -----------------------------
  // Instructions
  // -----------------------------
  String getInstruction(String from, String to) {
    if (!graph.containsKey(from)) return "Invalid path.";
    for (var edge in graph[from]!) {
      if (edge.to == to) {
        return "${edge.action} for about ${edge.distance} meters, towards $to";
      }
    }
    return "No instruction available.";
  }

  void debugGraph() {
    graph.forEach((node, edges) {
      print("Node: $node");
      for (var e in edges) {
        print("  -> ${e.to} (${e.distance}m, ${e.action})");
      }
    });
  }
}
