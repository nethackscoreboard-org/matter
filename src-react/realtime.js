// ugly
function Win(props) {
  return (
    <tr class="win">
      <td id="asc1" class="numeric">{props.index}</td>
      <td>{props.server}</td>
      <td>{props.variant}</td>
      <td>{props.version}</td>
      <td>{props.name}</td>
      <td>{props.role}-{props.race}-{props.gender}-{props.align}</td>
      <td class="numeric"><a href="{props.dumpurl}">{props.points}</a></td>
      <td class="numeric">{props.turns}</td>
      <td class="numeric">{props.realtime}</td>
      <td class="numeric">{props.deathlev}/{props.maxlvl}</td>
      <td class="numeric">{props.hp}/{props.maxhp}</td>
      <td>{props.endtime_fmt}</td>
      <td class="numeric">{props.conduct_cnt}</td>
      <td>{props.conducts}</td>
    </tr>
  )
}

// OMG SO BOILERPLATE SUCH WOW
class RtTable extends React.Component {
  render() {
    const wins = get_realtime().map((win, index) => {
      <Win
        index={index}
        server={win.server}
        variant={win.variant}
        version={win.version}
        name={win.name}
        role={win.role}
        race={win.race}
        gender={win.gender}
        align={win.align}
        dumpurl={win.dumpurl}
        points={win.points}
        turns={win.turns}
        realtime={win.realtime}
        deathlev={win.deathlev}
        maxlvl={win.maxlvl}
        hp={win.hp}
        maxhp={win.maxhp}
        endtime_fmt={win.endtime_fmt}
        conduct_cnt={win.conduct_cnt}
        conducts={win.conducts}
      />
    });

    // this really needs work
    return (
      <table class="bordered">
        <thead>
          <tr>
            <th>&nbsp;</th>
            <th>srv</th>
            <th>var</th>
            <th>ver</th>
            <th>name</th>
            <th>character</th>
            <th>points</th>
            <th>turns&nbsp;&nbsp;</th>
            <th>duration</th>
            <th>dlvl&nbsp;</th>
            <th>HP</th>
            <th>time</th>
            <th colspan="2">conducts</th>
          </tr>
        </thead>
        <tbody>
          {wins}
        </tbody>
      </table>
    );
  }
}

// fetch JSON data from Actix REST API
function get_realtime() {
}