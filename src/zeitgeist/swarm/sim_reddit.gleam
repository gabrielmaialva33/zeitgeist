import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type RedditComment {
  RedditComment(author: String, content: String, tick: Int, upvotes: Int)
}

pub type RedditThread {
  RedditThread(
    author: String,
    title: String,
    body: String,
    community: String,
    tick: Int,
    upvotes: Int,
    comments: List(RedditComment),
  )
}

pub type RedditMsg {
  CreateThread(thread: RedditThread)
  AddComment(index: Int, comment: RedditComment)
  UpvoteThread(index: Int)
  GetThreads(community: String, limit: Int, reply_to: Subject(List(RedditThread)))
  ThreadCount(reply_to: Subject(Int))
  RedditStop
}

type RedditState {
  RedditState(world_id: String, threads: List(RedditThread))
}

pub fn start(
  world_id: String,
) -> Result(Subject(RedditMsg), actor.StartError) {
  let init_state = RedditState(world_id: world_id, threads: [])
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn create_thread(rd: Subject(RedditMsg), thread: RedditThread) -> Nil {
  process.send(rd, CreateThread(thread))
}

pub fn add_comment(
  rd: Subject(RedditMsg),
  index: Int,
  comment: RedditComment,
) -> Nil {
  process.send(rd, AddComment(index, comment))
}

pub fn upvote_thread(rd: Subject(RedditMsg), index: Int) -> Nil {
  process.send(rd, UpvoteThread(index))
}

pub fn get_threads(
  rd: Subject(RedditMsg),
  community: String,
  limit: Int,
) -> List(RedditThread) {
  process.call(rd, waiting: 5000, sending: fn(reply_to) {
    GetThreads(community, limit, reply_to)
  })
}

pub fn thread_count(rd: Subject(RedditMsg)) -> Int {
  process.call(rd, waiting: 5000, sending: fn(reply_to) {
    ThreadCount(reply_to)
  })
}

pub fn stop(rd: Subject(RedditMsg)) -> Nil {
  process.send(rd, RedditStop)
}

fn handle_message(
  state: RedditState,
  msg: RedditMsg,
) -> actor.Next(RedditState, RedditMsg) {
  case msg {
    CreateThread(thread) -> {
      let new_threads = [thread, ..state.threads]
      actor.continue(RedditState(..state, threads: new_threads))
    }

    AddComment(idx, comment) -> {
      let updated =
        list.index_map(state.threads, fn(t, i) {
          case i == idx {
            True -> RedditThread(..t, comments: [comment, ..t.comments])
            False -> t
          }
        })
      actor.continue(RedditState(..state, threads: updated))
    }

    UpvoteThread(idx) -> {
      let updated =
        list.index_map(state.threads, fn(t, i) {
          case i == idx {
            True -> RedditThread(..t, upvotes: t.upvotes + 1)
            False -> t
          }
        })
      actor.continue(RedditState(..state, threads: updated))
    }

    GetThreads(community, limit, reply_to) -> {
      let filtered =
        list.filter(state.threads, fn(t) { t.community == community })
      let result = list.take(filtered, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }

    ThreadCount(reply_to) -> {
      process.send(reply_to, list.length(state.threads))
      actor.continue(state)
    }

    RedditStop -> actor.stop()
  }
}
