package fluid

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// --- CONSTANTS ---
WIN_WIDTH :: 400
WIN_HEGIHT :: 400
CELL_SIZE :: 16
NUM_COL :: WIN_HEGIHT / CELL_SIZE
NUM_ROW :: WIN_WIDTH / CELL_SIZE

MaxValue: f32 = 1.0 // The normal, un-pressurized mass of a full water cell
MinValue: f32 = 0.005 // Ignore cells that are almost dry
MaxCompress: f32 = 0.02 // How much excess water a cell can store, compared to the cell above it
MinFlow: f32 = 0.005
Maxflow: f32 = 4.0
FlowSpeed: f32 = 1.0

// --- TYPES ---
Cell_Type :: enum {
	water,
	block,
	nothing,
}

Cell :: struct {
	pos:    rl.Vector2,
	liquid: f32,
	type:   Cell_Type,
}


draw_grid :: proc() {
	for i in 0 ..< NUM_ROW {
		rl.DrawLine(cast(i32)(i * CELL_SIZE), 0, cast(i32)(i * CELL_SIZE), WIN_HEGIHT, rl.BLACK)
	}
	for i in 0 ..< NUM_COL {
		rl.DrawLine(0, cast(i32)(i * CELL_SIZE), WIN_WIDTH, cast(i32)(i * CELL_SIZE), rl.BLACK)
	}
}


calcaute_flow_value :: proc(remaining_value: f32, next_cell: Cell) -> f32 {
	sum: f32 = remaining_value + next_cell.liquid
	v: f32 = 0.0
	if (sum <= MaxValue) {
		v = MaxValue
	} else if (sum < 2 * MaxValue + MaxCompress) {
		v = (MaxValue * MaxValue + sum * MaxCompress) / (MaxValue + MaxCompress)
	} else {
		v = (sum + MaxCompress) / 2.0
	}

	return v
}


do_simulate :: proc(front_buffer: ^[NUM_ROW][NUM_COL]Cell) {
	back_buffer: [NUM_ROW][NUM_COL]Cell
	for i in 0 ..< NUM_ROW {
		for j in 0 ..< NUM_COL {
			back_buffer[i][j] = front_buffer[i][j]
		}
	}

	for i in 0 ..< NUM_ROW {
		for j in 0 ..< NUM_COL {
			cell := front_buffer[i][j]

			if cell.type == .block {
				back_buffer[i][j].liquid = 0.0
				continue
			}
			if cell.liquid < MinValue {
				back_buffer[i][j].liquid = 0.0
				continue
			}

			remaining_value := cell.liquid
			flow: f32 = 0.0
			current_back_cell := &back_buffer[i][j]

			// FLOW DOWN (BOTTOM CELL)
			if j + 1 < NUM_COL && front_buffer[i][j + 1].type != .block {
				bottom_cell := front_buffer[i][j + 1]
				flow = calcaute_flow_value(remaining_value, bottom_cell) - bottom_cell.liquid

				if flow > MinFlow {flow *= FlowSpeed}
				flow = math.max(flow, 0)
				flow = math.min(Maxflow, flow)
				flow = math.min(remaining_value, flow)

				if flow != 0 {
					remaining_value -= flow
					current_back_cell.liquid -= flow
					back_buffer[i][j + 1].liquid += flow
				}
			}

			if remaining_value < MinValue {
				current_back_cell.liquid -= remaining_value
				continue
			}

			// FLOW RIGHT (i+1)
			if i + 1 < NUM_ROW && front_buffer[i + 1][j].type != .block {
				right_cell := front_buffer[i + 1][j]
				flow = (remaining_value - right_cell.liquid) / 2.0

				if flow > MinFlow {flow *= FlowSpeed}
				flow = math.max(flow, 0)
				flow = math.min(Maxflow, flow)
				flow = math.min(remaining_value, flow)

				if flow != 0 {
					remaining_value -= flow
					current_back_cell.liquid -= flow
					back_buffer[i + 1][j].liquid += flow
				}
			}

			if remaining_value < MinValue {
				current_back_cell.liquid -= remaining_value
				continue
			}

			///  FLOW LEFT (i-1)
			if i - 1 >= 0 && front_buffer[i - 1][j].type != .block {
				left_cell := front_buffer[i - 1][j]
				flow = (remaining_value - left_cell.liquid) / 2.0

				if flow > MinFlow {flow *= FlowSpeed}
				flow = math.max(flow, 0)
				flow = math.min(Maxflow, flow)
				flow = math.min(remaining_value, flow)

				if flow != 0 {
					remaining_value -= flow
					current_back_cell.liquid -= flow
					back_buffer[i - 1][j].liquid += flow
				}
			}

			if remaining_value < MinValue {
				current_back_cell.liquid -= remaining_value
				continue
			}

			/// FLOW UP (TOP CELL)
			if j - 1 >= 0 && front_buffer[i][j - 1].type != .block {
				top_cell := front_buffer[i][j - 1]
				flow = remaining_value - MaxValue

				if flow > MinFlow {flow *= FlowSpeed}
				flow = math.max(flow, 0)
				flow = math.min(Maxflow, flow)
				flow = math.min(remaining_value, flow)

				if flow != 0 {
					remaining_value -= flow
					current_back_cell.liquid -= flow
					back_buffer[i][j - 1].liquid += flow
				}
			}

			if remaining_value < MinValue {
				current_back_cell.liquid -= remaining_value
				continue
			}
		}
	}

	for i in 0 ..< NUM_ROW {
		for j in 0 ..< NUM_COL {
			front_buffer[i][j] = back_buffer[i][j]
		}
	}
}

// Handles user input for adding fluid.
hanlde_input :: proc(Cell_Grid: ^[NUM_ROW][NUM_COL]Cell) {
	if rl.IsMouseButtonDown(.LEFT) {
		mouse_pos := rl.GetMousePosition()
		i := cast(int)(mouse_pos.x / CELL_SIZE)
		j := cast(int)(mouse_pos.y / CELL_SIZE)
		if i >= 0 && i < NUM_ROW && j >= 0 && j < NUM_COL {
			Cell_Grid[i][j].liquid = 5.0
			Cell_Grid[i][j].type = .water
		}
	}
}

draw_fluid :: proc(Cell_Grid: ^[NUM_ROW][NUM_COL]Cell) {
	for i in 0 ..< NUM_ROW {
		for j in 0 ..< NUM_COL {

			cell: Cell
			cell = Cell_Grid[i][j]
			if Cell_Grid[i][j].type == .water {
				height := cast(i32)(cell.liquid * cast(f32)CELL_SIZE)
				empty_space: f32 = 1.0 - math.min(cell.liquid, 1.0)
				temp: i32 = cast(i32)(empty_space * 10.0)

				rl.DrawRectangle(
					cast(i32)(i * CELL_SIZE),
					cast(i32)(j * CELL_SIZE) + temp,
					CELL_SIZE,
					height,
					rl.BLUE,
				)
			}
		}
	}
}

// The main entry point of the program.
main :: proc() {
	Cell_gird: [NUM_ROW][NUM_COL]Cell

	for i in 0 ..< NUM_ROW {
		for j in 0 ..< NUM_COL {
			Cell_gird[i][j] = Cell {
				pos    = {cast(f32)j * CELL_SIZE, cast(f32)i * CELL_SIZE},
				liquid = 0.0,
				type   = .nothing,
			}
		}
	}
	rl.InitWindow(WIN_WIDTH, WIN_HEGIHT, "2d fluid simulation with celluar automata")
	rl.SetTargetFPS(60) // Good practice to set FPS

	for !rl.WindowShouldClose() {


		hanlde_input(&Cell_gird)
		do_simulate(&Cell_gird)
		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)
		draw_fluid(&Cell_gird)
		draw_grid()

		rl.EndDrawing()
	}

	rl.CloseWindow() // Manual cleanup since defer is not used
}
