import .ExpressionExplorer
import .ExpressionExplorer: join_funcname_parts, SymbolsState, FunctionNameSignaturePair

"Return a copy of `old_topology`, but with recomputed results from `cells` taken into account."
function updated_topology(old_topology::NotebookTopology, notebook::Notebook, cells)
	
	updated_codes = Dict{Cell,ExprAnalysisCache}()
	updated_nodes = Dict{Cell,ReactiveNode}()
	unresolved_cells = Set{Cell}()
	for cell in cells
		if !(old_topology.codes[cell].code === cell.code)
			new_code = updated_codes[cell] = ExprAnalysisCache(notebook, cell)
			new_symstate = new_code.parsedcode |>
				ExpressionExplorer.try_compute_symbolreferences
			new_reactive_node = ReactiveNode(new_symstate)

			updated_nodes[cell] = new_reactive_node
		end

		new_reactive_node = get(updated_nodes, cell, old_topology.nodes[cell])
		if !isempty(new_reactive_node.macrocalls)
			# The unresolved cells are the cells for wich we cannot create
			# a ReactiveNode yet, because they contains macrocalls.
			push!(unresolved_cells, cell) 
		end
	end
	new_codes = merge(old_topology.codes, updated_codes)
	new_nodes = merge(old_topology.nodes, updated_nodes)
	new_unresolved_cells = union(old_topology.unresolved_cells, unresolved_cells)

	for removed_cell in setdiff(keys(old_topology.nodes), notebook.cells)
		delete!(new_nodes, removed_cell)
		delete!(new_codes, removed_cell)
		delete!(new_unresolved_cells, removed_cell)
	end

	NotebookTopology(nodes=new_nodes, codes=new_codes, unresolved_cells=new_unresolved_cells)
end
