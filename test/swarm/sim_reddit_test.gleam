import gleeunit
import gleeunit/should
import zeitgeist/swarm/sim_reddit

pub fn main() {
  gleeunit.main()
}

pub fn create_and_get_thread_test() {
  let assert Ok(rd) = sim_reddit.start("world1")

  let thread =
    sim_reddit.RedditThread(
      author: "alice",
      title: "Gleam is amazing",
      body: "I love functional programming",
      community: "programming",
      tick: 1,
      upvotes: 0,
      comments: [],
    )

  sim_reddit.create_thread(rd, thread)

  let threads = sim_reddit.get_threads(rd, "programming", 10)
  should.equal(1, list_length(threads))

  sim_reddit.stop(rd)
}

pub fn add_comment_test() {
  let assert Ok(rd) = sim_reddit.start("world2")

  let thread =
    sim_reddit.RedditThread(
      author: "bob",
      title: "What's your favorite language?",
      body: "Mine is Gleam",
      community: "dev",
      tick: 1,
      upvotes: 0,
      comments: [],
    )

  sim_reddit.create_thread(rd, thread)

  let comment =
    sim_reddit.RedditComment(
      author: "carol",
      content: "Gleam for sure!",
      tick: 2,
      upvotes: 0,
    )

  sim_reddit.add_comment(rd, 0, comment)

  let threads = sim_reddit.get_threads(rd, "dev", 10)
  let assert [t] = threads
  should.equal(1, list_length(t.comments))

  sim_reddit.stop(rd)
}

pub fn upvote_thread_test() {
  let assert Ok(rd) = sim_reddit.start("world3")

  let thread =
    sim_reddit.RedditThread(
      author: "dave",
      title: "Hot take",
      body: "Tabs are better than spaces",
      community: "drama",
      tick: 1,
      upvotes: 0,
      comments: [],
    )

  sim_reddit.create_thread(rd, thread)
  sim_reddit.upvote_thread(rd, 0)
  sim_reddit.upvote_thread(rd, 0)
  sim_reddit.upvote_thread(rd, 0)

  let threads = sim_reddit.get_threads(rd, "drama", 10)
  let assert [t] = threads
  should.equal(3, t.upvotes)

  sim_reddit.stop(rd)
}

pub fn filter_by_community_test() {
  let assert Ok(rd) = sim_reddit.start("world4")

  sim_reddit.create_thread(
    rd,
    sim_reddit.RedditThread(
      author: "a",
      title: "Gleam thread",
      body: "body",
      community: "gleam",
      tick: 1,
      upvotes: 0,
      comments: [],
    ),
  )
  sim_reddit.create_thread(
    rd,
    sim_reddit.RedditThread(
      author: "b",
      title: "Python thread",
      body: "body",
      community: "python",
      tick: 2,
      upvotes: 0,
      comments: [],
    ),
  )
  sim_reddit.create_thread(
    rd,
    sim_reddit.RedditThread(
      author: "c",
      title: "Another Gleam thread",
      body: "body",
      community: "gleam",
      tick: 3,
      upvotes: 0,
      comments: [],
    ),
  )

  let gleam_threads = sim_reddit.get_threads(rd, "gleam", 10)
  should.equal(2, list_length(gleam_threads))

  let python_threads = sim_reddit.get_threads(rd, "python", 10)
  should.equal(1, list_length(python_threads))

  sim_reddit.stop(rd)
}

pub fn thread_count_test() {
  let assert Ok(rd) = sim_reddit.start("world5")

  sim_reddit.create_thread(
    rd,
    sim_reddit.RedditThread(
      author: "a",
      title: "T1",
      body: "b1",
      community: "x",
      tick: 1,
      upvotes: 0,
      comments: [],
    ),
  )
  sim_reddit.create_thread(
    rd,
    sim_reddit.RedditThread(
      author: "b",
      title: "T2",
      body: "b2",
      community: "y",
      tick: 2,
      upvotes: 0,
      comments: [],
    ),
  )

  let count = sim_reddit.thread_count(rd)
  should.equal(2, count)

  sim_reddit.stop(rd)
}

fn list_length(lst: List(a)) -> Int {
  case lst {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
