import gleeunit
import gleeunit/should
import zeitgeist/swarm/sim_twitter

pub fn main() {
  gleeunit.main()
}

pub fn post_and_get_timeline_test() {
  let assert Ok(tw) = sim_twitter.start("world1")

  let tweet =
    sim_twitter.Tweet(
      author: "alice",
      content: "Hello world!",
      tick: 1,
      likes: 0,
      retweets: 0,
    )

  sim_twitter.post_tweet(tw, tweet)

  let timeline = sim_twitter.get_timeline(tw, 10)
  should.equal(1, list_length(timeline))

  sim_twitter.stop(tw)
}

pub fn like_and_retweet_update_counts_test() {
  let assert Ok(tw) = sim_twitter.start("world2")

  let tweet =
    sim_twitter.Tweet(
      author: "bob",
      content: "Gleam is great!",
      tick: 1,
      likes: 0,
      retweets: 0,
    )

  sim_twitter.post_tweet(tw, tweet)
  sim_twitter.like_tweet(tw, 0)
  sim_twitter.like_tweet(tw, 0)
  sim_twitter.retweet_tweet(tw, 0)

  let timeline = sim_twitter.get_timeline(tw, 10)
  let assert [t] = timeline
  should.equal(2, t.likes)
  should.equal(1, t.retweets)

  sim_twitter.stop(tw)
}

pub fn most_recent_first_test() {
  let assert Ok(tw) = sim_twitter.start("world3")

  let t1 =
    sim_twitter.Tweet(
      author: "alice",
      content: "First tweet",
      tick: 1,
      likes: 0,
      retweets: 0,
    )
  let t2 =
    sim_twitter.Tweet(
      author: "bob",
      content: "Second tweet",
      tick: 2,
      likes: 0,
      retweets: 0,
    )
  let t3 =
    sim_twitter.Tweet(
      author: "carol",
      content: "Third tweet",
      tick: 3,
      likes: 0,
      retweets: 0,
    )

  sim_twitter.post_tweet(tw, t1)
  sim_twitter.post_tweet(tw, t2)
  sim_twitter.post_tweet(tw, t3)

  let timeline = sim_twitter.get_timeline(tw, 10)
  let assert [first, second, third] = timeline
  should.equal("Third tweet", first.content)
  should.equal("Second tweet", second.content)
  should.equal("First tweet", third.content)

  sim_twitter.stop(tw)
}

pub fn tweet_count_test() {
  let assert Ok(tw) = sim_twitter.start("world4")

  sim_twitter.post_tweet(
    tw,
    sim_twitter.Tweet(
      author: "alice",
      content: "A",
      tick: 1,
      likes: 0,
      retweets: 0,
    ),
  )
  sim_twitter.post_tweet(
    tw,
    sim_twitter.Tweet(
      author: "bob",
      content: "B",
      tick: 2,
      likes: 0,
      retweets: 0,
    ),
  )

  let count = sim_twitter.tweet_count(tw)
  should.equal(2, count)

  sim_twitter.stop(tw)
}

pub fn timeline_limit_test() {
  let assert Ok(tw) = sim_twitter.start("world5")

  sim_twitter.post_tweet(
    tw,
    sim_twitter.Tweet(
      author: "a",
      content: "1",
      tick: 1,
      likes: 0,
      retweets: 0,
    ),
  )
  sim_twitter.post_tweet(
    tw,
    sim_twitter.Tweet(
      author: "b",
      content: "2",
      tick: 2,
      likes: 0,
      retweets: 0,
    ),
  )
  sim_twitter.post_tweet(
    tw,
    sim_twitter.Tweet(
      author: "c",
      content: "3",
      tick: 3,
      likes: 0,
      retweets: 0,
    ),
  )

  let timeline = sim_twitter.get_timeline(tw, 2)
  should.equal(2, list_length(timeline))

  sim_twitter.stop(tw)
}

fn list_length(lst: List(a)) -> Int {
  case lst {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
