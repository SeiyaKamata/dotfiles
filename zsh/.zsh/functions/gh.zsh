get_pull_request_timeline() {
  local owner="$1"
  local repo="$2"
  local pr="$3"

  if [[ -z "$owner" || -z "$repo" || -z "$pr" ]]; then
    echo "usage: pr-times <owner> <repo> <pr-number>"
    return 1
  fi

  # 依存チェック
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI 'gh' が見つかりません。brew install gh && gh auth login"
    return 1
  fi
  local JQ
  if command -v jq >/dev/null 2>&1; then
    JQ=jq
  elif command -v jaq >/dev/null 2>&1; then
    JQ=jaq
  else
    echo "error: jq/jaq が見つかりません。brew install jq（または）brew install jaq"
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh の認証が必要です。gh auth login を実行してください。"
    return 1
  fi

  # GraphQL クエリを変数に格納（クォート地獄を避ける）
  local QUERY
  QUERY=$(cat <<'__Q__'
query ($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      number title author{login}
      createdAt mergedAt closedAt
      timelineItems(first: 250, itemTypes:[ISSUE_COMMENTED, PULL_REQUEST_REVIEW]) {
        nodes {
          __typename
          ... on IssueComment { createdAt author{login} }
          ... on PullRequestReview { submittedAt state author{login} }
        }
      }
    }
  }
}
__Q__
)

  gh api graphql -f query="$QUERY" -F owner="$owner" -F repo="$repo" -F number="$pr" \
  | $JQ -r '
    def mins($a;$b):
      if ($a==null or $b==null) then null
      else ((($a|fromdateiso8601)-($b|fromdateiso8601))/60|floor) end;

    .data.repository.pullRequest as $pr
    | ($pr.timelineItems.nodes
        | map(
            if .__typename=="IssueComment" then {t:.createdAt, k:"reaction"}
            elif .__typename=="PullRequestReview" then {t:.submittedAt, k:(if .state=="APPROVED" then "approved" else "review" end)}
            else empty end
          )
        | sort_by(.t)
      ) as $ev
    | {
        number: ("#" + ($pr.number|tostring)),
        title: $pr.title,
        author: $pr.author.login,
        createdAt: $pr.createdAt,
        firstReactionAt: ($ev[]? | select(.k=="reaction") | .t) // null,
        firstReviewAt:   ($ev[]? | select(.k=="review")   | .t) // null,
        approvedAt:      ($ev[]? | select(.k=="approved") | .t) // null,
        mergedAt:        $pr.mergedAt
      }
    | ([
        "PR","Author","Created","FirstReaction","FirstReview","Approved","Merged",
        "ToFirstReaction(min)","ToFirstReview(min)","FromApproveToMerge(min)","ToMerge(min)"
       ]|@tsv),
      ([
        .number,.author,.createdAt,
        (.firstReactionAt // "-"),(.firstReviewAt // "-"),(.approvedAt // "-"),(.mergedAt // "-"),
        (mins(.firstReactionAt;.createdAt) // "-"),
        (mins(.firstReviewAt;.createdAt) // "-"),
        (mins(.mergedAt;.approvedAt) // "-"),
        (mins(.mergedAt;.createdAt) // "-")
      ]|@tsv)
  ' | column -t -s $'\t'
}

