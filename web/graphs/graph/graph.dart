import "dart:html";
import "dart:math" as Math;

import "package:CommonLib/Random.dart";
import "package:CommonLib/Utility.dart";

/*class Graph {

    late Set<GraphNode> nodes;
    late List<List<GraphNode>> _layers;

    Graph() {
        nodes = <GraphNode>{};
    }

    bool add(GraphNode node) => nodes.add(node);
    bool remove(GraphNode node) => nodes.remove(node);

    Element drawGraph() {


        _calculateDepth();
        final Tuple<int,int> dim = _sortIntoLayers();

        final int layers = dim.first;
        final int layerwidth = dim.second;
        const int xgap = 80;
        const int ygap = 10;

        final List<int> depths = new List<int>.filled(layers+1, 0);
        int width = 0;
        
        for (final GraphNode node in nodes) {
            final CanvasElement img = node.getImage();
            if (img == null) { continue; }
            
            width = Math.max(width, img.height!);
            depths[node.depth] = Math.max(depths[node.depth], img.width!);
        }

        final int graphwidth = joinCollection(depths, convert: (int i) => i, combine: (int a, int b) => a+b) + xgap * (layers + 1);
        final int graphheight = width * layerwidth + ygap * (layerwidth + 1);

        final CanvasElement canvas = new CanvasElement(width: graphwidth, height: graphheight);
        final CanvasRenderingContext2D ctx = canvas.context2D;

        for (final GraphNode node in nodes) {
            final CanvasElement img = node.getImage();
            if (img == null) { continue; }

            final Tuple<int,int> pos = _drawPos(node, xgap, ygap, depths, width);
            final int x = pos.first;
            final int y = pos.second;

            ctx.drawImage(node.getImage(), x,y);

            for (final GraphNode child in node.children) {
                final CanvasElement cimg = child.getImage();
                if (cimg == null) { continue; }

                final num px = x + img.width;
                final num py = y + img.height * 0.5;

                final Tuple<int,int> cpos = _drawPos(child, xgap, ygap, depths, width);

                final num cx = cpos.first;
                final num cy = cpos.second + cimg.height * 0.5;

                ctx
                    ..beginPath()
                    ..moveTo(px, py)
                    ..lineTo(cx, cy)
                    ..stroke();
            }
        }

        return canvas;
    }

    /*void _drawNode(CanvasRenderingContext2D ctx, GraphNode node, int xgap, int ygap, List<int> depths, int width) {
        final Tuple<int,int> pos = _drawPos(node, xgap, ygap, depths, width);

        ctx.drawImage(node.getImage(), pos.first, pos.second);
    }*/

    Tuple<int,int> _drawPos(GraphNode node, int xgap, int ygap, List<int> depths, int width) {
        int x = xgap;
        for (int i=0; i<node.depth; i++) {
            x += depths[i] + xgap;
        }
        final int y = node.position.floor() * (width + ygap);

        return new Tuple<int,int>(x,y);
    }

    Tuple<int,int> _sortIntoLayers() {
        int count = 0;
        for (final GraphNode node in nodes) {
            count = Math.max(count, node.depth);
        }

        _layers = new List<List<GraphNode>>(count+1);
        for (int i=0; i<count+1; i++) {
            _layers[i] = <GraphNode>[];
        }

        for (final GraphNode node in nodes) {
            _layers[node.depth].add(node);
        }
        int size = 0;
        for (final List<GraphNode> layer in _layers) {
            size = Math.max(size, layer.length);
        }
        size += 6; // breathing room?

        for (final List<GraphNode> layer in _layers) {
            bool flop = false;
            while(layer.length < size) {
                flop = !flop;
                if (flop) {
                    layer.add(new DummyGraphNode());
                } else {
                    layer.insert(0, new DummyGraphNode());
                }
            }
            //layer.shuffle();
            for (int i=0; i < size; i++) {
                layer[i]..position = i.toDouble()..layersize = size;
            }
        }

        int iter = 0;
        bool done = false;
        while (!done) {
            //print("Loop $iter ###################################");
            iter++;
            if (iter > 500) { break; }
            done = true; // set false when we move something

            //print("Start #################################################################################################");
            int layernum = 0;
            for (final List<GraphNode> layer in _layers) {
                layernum++;
                //print("Layer $layernum ------------------");

                final Map<GraphNode, double> startpos = <GraphNode,double>{};

                final List<GraphNode> dummies = <GraphNode>[];
                final Map<GraphNode, Tuple<double,double>> reals = <GraphNode, Tuple<double,double>>{};

                // POSITION ##########################################################
                for (int i=0; i < size; i++) {
                    final GraphNode n = layer[i];
                    n.position = i.toDouble();
                    startpos[n] = n.position;
                }
                for (int i=0; i < size; i++) {
                    final GraphNode n = layer[i];
                    if (n is DummyGraphNode) {
                        dummies.add(n);
                    } else {
                        final double pos = n.averagepos();
                        reals[n] = new Tuple<double,double>(pos,pos);
                    }
                }

                // NUDGE ##########################################################

                final Random nudgeRand = new Random(layernum);
                bool flop = false;
                bool cont = true;
                int nudgeIterations = 0;
                while(cont) {
                    cont = false;
                    nudgeIterations++;
                    if (nudgeIterations > 1000) { break; }

                    for (final GraphNode node in reals.keys) {
                        double offset = 0.0;
                        int count = 0;

                        for (final GraphNode other in reals.keys) {
                            if (node == other) {
                                continue;
                            }

                            double diff = reals[node].first - reals[other].first;
                            final double absdiff = diff.abs();

                            if (absdiff < 1.0) {
                                if (absdiff < 0.01) {
                                    diff += (diff < 0 ? -1 : 1) * (flop ? -0.01 : 0.01);
                                    flop = !flop;
                                }
                                offset += diff.sign * (0.25 + nudgeRand.nextDouble(0.8));
                                count++;
                                cont = true;
                            }
                        }

                        if (count > 0) {
                            offset /= count;
                            if (offset + reals[node].first < 0) {
                                offset += 0.5;
                            } else if (offset + reals[node].first > size-1) {
                                offset -= 0.5;
                            }

                            reals[node].second += offset;
                        }
                    }

                    for (final GraphNode node in reals.keys) {
                        //print("old: ${reals[node].first}, new: ${reals[node].second}");
                        reals[node].first = reals[node].second;
                    }
                }
                //print("Nudge Iterations: $nudgeIterations");

                for (final GraphNode node in reals.keys) {
                    node.position = node.position * 0.25 + reals[node].first * 0.75;
                }

                // FILL BLANKS ##########################################################

                final List<int> empty = <int>[];

                for (int i=0; i<size; i++) {
                    bool ok = true;
                    for (final GraphNode node in reals.keys) {
                        final double diff = i - reals[node].first;
                        if (diff.abs() <= 0.5) {
                            ok = false;
                            break;
                        }
                    }

                    if (ok) {
                        empty.add(i);
                    }
                }

                //print("empties: ${empty.length}, dummies: ${dummies.length}");

                for (final GraphNode node in dummies) {
                    int newpos = 0;
                    if (empty.isEmpty) {
                        newpos = flop ? -2 : size + 1;
                        flop = !flop;
                    } else {
                        newpos = nudgeRand.pickFrom(empty);
                        empty.remove(newpos);
                    }
                    node.position = newpos.toDouble();
                }

                // SORT ##########################################################

                layer.sort((GraphNode a, GraphNode b) => a.position.compareTo(b.position));

                for (int i=0; i < size; i++) {
                    layer[i].position = i.toDouble();
                }

                for (final GraphNode n in layer) {
                    final double start = startpos[n];
                    final double end = n.position;

                    if (!(n is DummyGraphNode) && start != end) {
                        //print("$start -> $end");
                        done = false;
                    }
                }
            }
        }



        return new Tuple<int,int>(count, size);
    }

    void _calculateDepth() {
        for (final GraphNode node in nodes) {
            node.depth = 0;
        }

        final Set<GraphNode> open = <GraphNode>{};
        final Set<GraphNode> closed = <GraphNode>{};
        int lowest = 0;
        open.add(nodes.first);
        GraphNode node;

        while (!open.isEmpty) {
            node = open.first;
            open.remove(node);
            closed.add(node);

            lowest = Math.min(node.depth, lowest);

            for (final GraphNode n in node.parents) {
                if (!closed.contains(n)) {
                    open.add(n);
                    n.depth = node.depth - 1;
                }
            }

            for (final GraphNode n in node.children) {
                if (!closed.contains(n)) {
                    open.add(n);
                    n.depth = node.depth + 1;
                }
            }
        }

        for (final GraphNode n in nodes) {
            n.depth -= lowest;
        }
    }
}

class GraphNode {
    Set<GraphNode> parents = <GraphNode>{};
    Set<GraphNode> children = <GraphNode>{};

    int depth = 0;
    double position = 0.0;
    int layersize = 0;

    CanvasElement _image;

    CanvasElement getImage() {
        draw();
        return _image;
    }

    void draw() {
        if (_image != null) { return; }

        const int w = 75;
        const int h = 30;

        final CanvasElement canvas = new CanvasElement(width: w, height: h);
        _image = canvas;

        final CanvasRenderingContext2D ctx = canvas.context2D;

        ctx
            ..fillStyle="#FFFFFF"
            ..fillRect(0, 0, w, h)
            ..strokeStyle="#000000"
            ..strokeRect(0.5, 0.5, w-1, h-1)
            ..fillStyle="#000000"
            ..fillText(name(), 10, 18);
    }

    void addChild(GraphNode node) {
        children.add(node);
        node.parents.add(this);
    }
    void removeChild(GraphNode node) {
        children.remove(node);
        node.parents.remove(this);
    }

    double averagepos() {
        /*double dpos = this.position.toDouble();
        double ppos = parents.isEmpty ? -1 : joinCollection(parents, convert:(GraphNode n) => n.position.toDouble(), combine:(double a, double b) => a+b) / parents.length;
        double cpos = children.isEmpty ? -1 : joinCollection(children, convert:(GraphNode n) => n.position.toDouble(), combine:(double a, double b) => a+b) / children.length;

        double pweight = parents.isEmpty ? 0.0 : 0.3;
        double cweight = children.isEmpty ? 0.0 : 0.3;//6;
        double posweight = 0.0;

        double totalweight = pweight + cweight + posweight;
        pweight /= totalweight;
        cweight /= totalweight;
        posweight /= totalweight;

        print("dpos: $dpos, ppos: $ppos, cpos: $cpos (p: ${parents.length}, c: ${children.length})");

        return ppos * pweight + cpos * cweight + dpos * posweight;*/

        final List<double> pos = <double>[];
        pos.addAll(parents.map((GraphNode n) => n.position));
        pos.addAll(children.map((GraphNode n) => n.position));

        return pos.isEmpty ? this.position : (joinCollection(pos, convert:(double p) => p, combine:(double a, double b)=>a+b) / pos.length);
    }

    String name() => "0x${this.hashCode.toRadixString(16).padLeft(8, "0")}";
}

class DummyGraphNode extends GraphNode {
    @override
    CanvasElement getImage() => null;

    @override
    double averagepos() {
        final double pos = position.toDouble();
        return pos;// - (pos < 0.5 ? -0.1 : 0.1);
    }

    @override
    String name() => "D ${super.name()}";
}*/