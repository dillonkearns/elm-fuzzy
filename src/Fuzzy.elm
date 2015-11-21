module Fuzzy (match) where

{-| This is library for performing fuzzy string matching.

# Matching
@docs match

-}

import String
import Maybe

type alias Model = List Int

hayPenalty = 1
needlePenalty = 1000
movePenalty = 100

initialModel : Model
initialModel =
    []

{-| Calculate how many moves that is required to order the entries

quickPenalty [5,4,3,2,1] == 4
-}
quickPenalty : List Int -> Int
quickPenalty entries =
  if List.isEmpty entries
  then
    0
  else
    let
        head =
          List.head entries |> Maybe.withDefault 0
        tail =
          List.tail entries |> Maybe.withDefault []
        partition =
          List.partition (\e -> e < head) tail
        smaller =
          fst partition
        larger =
          snd partition
        penalty =
          if List.isEmpty smaller then 0 else 1
    in
        (quickPenalty smaller) + penalty + (quickPenalty larger)


{-| Calculate the fuzzy distance between two Strings.

    distance "test" "test" == 0
    distance "test" "tast" == 1001
-}
distance : String -> String -> Int
distance needle hay =
  let
      accumulate c indexList =
        let
            indexes =
                String.indexes (String.fromChar c) hay
            hayIndex =
                List.filter (\e -> not (List.member e indexList) ) indexes
                  |> List.head
        in
            case hayIndex of
              Just v ->
                indexList ++ [v]

              Nothing ->
                indexList
      accumulated =
        String.foldl accumulate initialModel needle
      mPenalty =
        (accumulated |> quickPenalty) * movePenalty
      hPenalty =
        (String.length hay - (accumulated |> List.length)) * hayPenalty
      nPenalty =
        (String.length needle - (accumulated |> List.length)) * needlePenalty
  in
      mPenalty + hPenalty + nPenalty


{-| Split a string based on a list of separators keeping the separators.
-}
dissect : List String -> List String -> List String
dissect separators strings =
  if List.isEmpty separators
  then
    strings
  else
    let
        head =
          List.head separators |> Maybe.withDefault ""
        tail =
          List.tail separators |> Maybe.withDefault []
        dissectEntry entry =
          let
              entryLength =
                String.length entry
              indexes =
                  String.indexes head entry
              separatorLength =
                String.length head
              slice index (prevIndex, sum) =
                let
                    precedingSlice =
                      if prevIndex == index
                      then
                        []
                      else
                        [String.slice prevIndex index entry]
                    separatorSlice =
                      [String.slice index (index + separatorLength) entry]
                in
                    (index+separatorLength, sum ++ precedingSlice ++ separatorSlice)
              result =
                List.foldl slice (0,[]) indexes
              first =
                snd result
              lastIndex =
                fst result
              last =
                if lastIndex == entryLength
                then
                  []
                else
                  [String.slice lastIndex entryLength entry]
          in
              first ++ last
        dissected =
          List.foldl (\e s -> s ++ dissectEntry e) [] strings
    in
        dissect tail dissected


{-| Perform fuzzy matching between a query String (needle) and a target String (hay).
The order of the arguments are significant. Lower score is better. Specifying some
separators will allow for partial matching within a sentence.

    Fuzzy.match [] "test" "test" == 0
    Fuzzy.match [] "tst" "test" == 1
    Fuzzy.match [] "test" "tste" == 100
    Fuzzy.match [] "test" "tst" == 1000
    Fuzzy.match ["/"] "/u/b/s" "/usr/local/bin/sh" == 5
    Fuzzy.match [] "/u/b/s" "/usr/local/bin/sh" == 211
    List.sortBy (Fuzzy.match [] "hrdevi") ["screen", "disk", "harddrive", "keyboard", "mouse", "computer"] == ["harddrive","keyboard","disk","screen","computer","mouse"]
-}
match : List String -> String -> String -> Int
match separators needle hay =
  let
      needles =
        dissect separators [needle]
      hays =
        dissect separators [hay]
      -- The best score for a needle against a list of hays
      minScore n hs =
        List.foldl (\e prev-> min (distance n e) prev) ((String.length n) * needlePenalty) hs
      -- Sentence logic, reduce hays on left and right side depending on current needle context
      reduceHays ns c hs =
        let
            -- Reduce the left side of hays, the second needle do not need to match the first hay and so on.
            reduceLeft ns c hs =
              List.drop c hs
            -- Reduce the right side of hays, the first needle do not need to match against the last hay if there are other needles and so on.
            reduceRight ns c hs =
              List.take ((List.length hs) - (ns - c - 1)) hs
            -- Pad the hay stack to prevent hay starvation if we have more needles than hays
            padHays ns hs =
              hs ++ (List.repeat (ns - (List.length hs)) "")
        in
            hs |> padHays ns |> reduceRight ns c |> reduceLeft ns c
  in
      fst (List.foldl (\n (prev, num) -> (((minScore n (reduceHays (List.length needles) num hays)) + prev), (num + 1)) ) (0, 0) needles)

