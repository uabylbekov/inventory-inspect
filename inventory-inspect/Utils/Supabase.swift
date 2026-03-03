//
//  Supabase.swift
//  inventory-inspect
//
//  Created by Uluk Abylbekov on 3/2/26.
//
import Supabase

let supabase = SupabaseClient(
    supabaseURL: EnvConfig.supabaseURL,
    supabaseKey: EnvConfig.supabaseKey
)

