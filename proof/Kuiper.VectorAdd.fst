module Kuiper.VectorAdd

#lang-pulse

open Kuiper
open Kuiper.Approximates

let spec (x y : real) : real = x +. y
let cell_result (x y : f64) : f64 = add x y

let cell_proof (x y : f64) (rx ry : real)
  : Lemma (requires x %~ rx /\ y %~ ry)
          (ensures cell_result x y %~ spec rx ry)
  = a_add x y rx ry

fn add_cell (a b out : gpu_ref f64)
  (#x #y #old : erased f64)
  preserves gpu
  requires a |-> x ** b |-> y ** out |-> old
  ensures  a |-> x ** b |-> y ** out |-> cell_result x y
{
  let av = gpu_read a;
  let bv = gpu_read b;
  gpu_write out (add av bv);
}
